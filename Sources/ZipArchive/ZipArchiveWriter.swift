import CZipZlib

/// Zip archive writer type
public final class ZipArchiveWriter<Storage: ZipWriteableStorage> {
    var reader: ZipArchiveReader<Storage>?
    var filesToAdd: [(fileHeader: Zip.FileHeader, bytes: [UInt8])]
    var storage: Storage
    var endOfCentralDirectoryRecord: Zip.EndOfCentralDirectory
    let directory: [Zip.FileHeader]

    public init() where Storage == ZipMemoryStorage<[UInt8]> {
        self.reader = nil
        self.filesToAdd = []
        self.storage = .init()
        self.endOfCentralDirectoryRecord = .init(
            diskNumber: 0,
            diskNumberCentralDirectoryStarts: 0,
            diskEntries: 0,
            totalEntries: 0,
            centralDirectorySize: 0,
            offsetOfCentralDirectory: 0,
            comment: ""
        )
        self.directory = []
    }

    convenience public init<Bytes: RangeReplaceableCollection>(bytes: Bytes) throws where Storage == ZipMemoryStorage<Bytes> {
        try self.init(storage: .init(bytes))
    }

    init(storage: Storage) throws {
        let reader = try ZipArchiveReader(storage)
        self.reader = reader
        self.filesToAdd = []
        self.storage = storage
        self.endOfCentralDirectoryRecord = reader.endOfCentralDirectoryRecord
        self.directory = try reader.readDirectory()
    }

    public func addFile(filename: String, contents: [UInt8]) throws {
        // Calculate CRC32
        let crc = contents.withUnsafeBytes { bytes in
            var crc = crc32(0xffff_ffff, nil, 0)
            crc = crc32(crc, bytes.baseAddress, numericCast(bytes.count))
            return crc
        }
        let compressedContents = try ZlibDeflateCompressor(windowBits: 15).deflate(from: contents)
        let fileHeader = Zip.FileHeader(
            versionNeeded: 20,
            flags: [],
            compressionMethod: .deflated,
            fileModificationTime: 0,
            fileModificationDate: 0,
            crc32: numericCast(crc),
            compressedSize: numericCast(compressedContents.count),
            uncompressedSize: numericCast(contents.count),
            filename: filename,
            extraFields: [],
            comment: "",
            diskStart: 0,
            internalAttribute: 0,
            externalAttributes: 0,
            offsetOfLocalHeader: 0
        )

        self.filesToAdd.append((fileHeader: fileHeader, bytes: compressedContents))
    }

    public func writeToBuffer() throws -> [UInt8].SubSequence where Storage == ZipMemoryStorage<[UInt8]> {
        try write()
        return self.storage.buffer.buffer
    }

    func write() throws {
        // read directory before we truncate it
        try self.storage.seek(endOfCentralDirectoryRecord.offsetOfCentralDirectory)
        // Zip files support a central directory larger then 0xffff_ffff but we don't
        let directory = try self.storage.read(numericCast(endOfCentralDirectoryRecord.centralDirectorySize))

        // truncate zip file
        try self.storage.truncate(endOfCentralDirectoryRecord.offsetOfCentralDirectory)

        // write new files
        for i in 0..<filesToAdd.count {
            let header = filesToAdd[i].fileHeader
            // Update offset of local header in file header
            filesToAdd[i].fileHeader.offsetOfLocalHeader = try self.storage.seekOffset(0)
            try writeLocalFileHeader(header)
            try storage.write(bytes: filesToAdd[i].bytes)
        }
        let centralDirectoryOffset = try storage.seekOffset(0)

        // write original directory
        try storage.write(bytes: directory)
        // write new files to directory
        for file in filesToAdd {
            try writeFileHeader(file.fileHeader)
        }
        let centralDirectoryEndOffset = try storage.seekOffset(0)

        endOfCentralDirectoryRecord.offsetOfCentralDirectory = centralDirectoryOffset
        endOfCentralDirectoryRecord.centralDirectorySize = centralDirectoryEndOffset - centralDirectoryOffset
        endOfCentralDirectoryRecord.diskEntries += numericCast(filesToAdd.count)
        endOfCentralDirectoryRecord.totalEntries += numericCast(filesToAdd.count)

        try writeEndOfCentralDirectory(endOfCentralDirectoryRecord)
    }

    func writeFileHeader(_ fileHeader: Zip.FileHeader) throws {
        var fileHeader = fileHeader
        let extraFieldsBuffer = getExtraFieldBuffer(&fileHeader)

        try self.storage.writeIntegers(
            Zip.fileHeaderSignature,
            Zip.versionMadeBy,
            fileHeader.versionNeeded,
            fileHeader.flags.rawValue,
            fileHeader.compressionMethod.rawValue,
            fileHeader.fileModificationTime,
            fileHeader.fileModificationDate,
            fileHeader.crc32,
            UInt32(fileHeader.compressedSize),
            UInt32(fileHeader.uncompressedSize),
            UInt16(fileHeader.filename.utf8.count),
            UInt16(extraFieldsBuffer.count),
            UInt16(fileHeader.comment.utf8.count),
            UInt16(fileHeader.diskStart),
            fileHeader.internalAttribute,
            fileHeader.externalAttributes,
            UInt32(fileHeader.offsetOfLocalHeader)
        )
        try self.storage.writeString(fileHeader.filename)
        try self.storage.write(bytes: extraFieldsBuffer)
        try self.storage.writeString(fileHeader.comment)
    }

    func writeLocalFileHeader(_ fileHeader: Zip.FileHeader) throws {
        var fileHeader = fileHeader
        let extraFields = getExtraFieldBuffer(&fileHeader)

        try self.storage.writeIntegers(
            Zip.localFileHeaderSignature,
            fileHeader.versionNeeded,
            fileHeader.flags.rawValue,
            fileHeader.compressionMethod.rawValue,
            fileHeader.fileModificationTime,
            fileHeader.fileModificationDate,
            fileHeader.crc32,
            UInt32(fileHeader.compressedSize),
            UInt32(fileHeader.uncompressedSize),
            UInt16(fileHeader.filename.utf8.count),
            UInt16(extraFields.count)
        )
        try self.storage.writeString(fileHeader.filename)
        try self.storage.write(bytes: extraFields)
    }

    func getExtraFieldBuffer(_ fileHeader: inout Zip.FileHeader) -> ArraySlice<UInt8> {
        let compressedSize32 = fileHeader.compressedSize > 0xffff_ffff ? 0xffff_ffff : numericCast(fileHeader.compressedSize)
        let uncompressedSize32 = fileHeader.uncompressedSize > 0xffff_ffff ? 0xffff_ffff : numericCast(fileHeader.uncompressedSize)
        let offsetOfLocalHeader32 = fileHeader.offsetOfLocalHeader > 0xffff_ffff ? 0xffff_ffff : numericCast(fileHeader.offsetOfLocalHeader)

        let includeZip64 = compressedSize32 == 0xffff_ffff || uncompressedSize32 == 0xffff_ffff || offsetOfLocalHeader32 == 0xffff_ffff

        var zip64ExtraFieldSize = includeZip64 ? 4 : 0
        if compressedSize32 == 0xffff_ffff { zip64ExtraFieldSize += 8 }
        if uncompressedSize32 == 0xffff_ffff { zip64ExtraFieldSize += 8 }
        if offsetOfLocalHeader32 == 0xffff_ffff { zip64ExtraFieldSize += 8 }
        let extraFieldsSize = fileHeader.extraFields.reduce(zip64ExtraFieldSize) { $0 + $1.data.count + 4 }

        var memoryBuffer = MemoryBuffer(size: extraFieldsSize)
        if includeZip64 {
            memoryBuffer.writeIntegers(Zip.ExtraFieldHeader.zip64.rawValue, UInt16(zip64ExtraFieldSize - 4))
            if uncompressedSize32 == 0xffff_ffff {
                memoryBuffer.writeInteger(fileHeader.uncompressedSize)
            }
            if compressedSize32 == 0xffff_ffff {
                memoryBuffer.writeInteger(fileHeader.compressedSize)
            }
            if offsetOfLocalHeader32 == 0xffff_ffff {
                memoryBuffer.writeInteger(fileHeader.offsetOfLocalHeader)
            }
        }
        for field in fileHeader.extraFields {
            memoryBuffer.writeIntegers(field.header.rawValue, UInt16(field.data.count))
            memoryBuffer.write(bytes: field.data)
        }
        return memoryBuffer.buffer
    }

    func writeZip64EndOfCentralDirectory(_ zip64EndOfCentralDirectory: Zip.Zip64EndOfCentralDirectory) throws {
        try self.storage.writeIntegers(
            Zip.zip64EndOfCentralDirectorySignature,
            Zip.versionMadeBy,
            zip64EndOfCentralDirectory.versionNeeded,  // version needed (zip64 requires v4.5)
            zip64EndOfCentralDirectory.diskNumber,
            zip64EndOfCentralDirectory.diskNumberCentralDirectoryStarts,
            zip64EndOfCentralDirectory.diskEntries,
            zip64EndOfCentralDirectory.totalEntries,
            zip64EndOfCentralDirectory.centralDirectorySize,
            zip64EndOfCentralDirectory.offsetOfCentralDirectory
        )
    }

    func writeZip64EndOfCentralLocator(_ zip64EndOfCentralLocator: Zip.Zip64EndOfCentralLocator) throws {
        try self.storage.writeIntegers(
            Zip.zip64EndOfCentralLocatorSignature,
            zip64EndOfCentralLocator.diskNumberCentralDirectoryStarts,
            zip64EndOfCentralLocator.relativeOffsetEndOfCentralDirectory,
            zip64EndOfCentralLocator.totalNumberOfDisks
        )
    }

    func writeEndOfCentralDirectory(_ endOfCentralDirectory: Zip.EndOfCentralDirectory) throws {
        let diskNumber16: UInt16 = endOfCentralDirectory.diskNumber > 0xffff ? 0xffff : numericCast(endOfCentralDirectory.diskNumber)
        let diskNumberCentralDirectoryStarts16: UInt16 =
            endOfCentralDirectory.diskNumberCentralDirectoryStarts > 0xffff
            ? 0xffff : numericCast(endOfCentralDirectory.diskNumberCentralDirectoryStarts)
        let diskEntries16: UInt16 = endOfCentralDirectory.diskEntries > 0xffff ? 0xffff : numericCast(endOfCentralDirectory.diskEntries)
        let totalEntries16: UInt16 = endOfCentralDirectory.totalEntries > 0xffff ? 0xffff : numericCast(endOfCentralDirectory.totalEntries)
        let centralDirectorySize32: UInt32 =
            endOfCentralDirectory.centralDirectorySize > 0xffff_ffff ? 0xffff_ffff : numericCast(endOfCentralDirectory.centralDirectorySize)
        let offsetOfCentralDirectory32: UInt32 =
            endOfCentralDirectory.offsetOfCentralDirectory > 0xffff_ffff ? 0xffff_ffff : numericCast(endOfCentralDirectory.offsetOfCentralDirectory)

        // do we need Zip64 records
        if diskNumber16 == 0xffff || diskNumberCentralDirectoryStarts16 == 0xffff || diskEntries16 == 0xffff || totalEntries16 == 0xffff
            || centralDirectorySize32 == 0xffff_ffff || offsetOfCentralDirectory32 == 0xffff_ffff
        {
            let zip64EndOfCentralDirectory = Zip.Zip64EndOfCentralDirectory(
                versionNeeded: 45,  // Zip64 requires 4.5
                diskNumber: endOfCentralDirectory.diskNumber,
                diskNumberCentralDirectoryStarts: endOfCentralDirectory.diskNumberCentralDirectoryStarts,
                diskEntries: endOfCentralDirectory.diskEntries,
                totalEntries: endOfCentralDirectory.totalEntries,
                centralDirectorySize: endOfCentralDirectory.centralDirectorySize,
                offsetOfCentralDirectory: endOfCentralDirectory.offsetOfCentralDirectory
            )
            try writeZip64EndOfCentralDirectory(zip64EndOfCentralDirectory)

            let zip64EndOfCentralLocator = Zip.Zip64EndOfCentralLocator(
                diskNumberCentralDirectoryStarts: endOfCentralDirectory.diskNumberCentralDirectoryStarts,
                relativeOffsetEndOfCentralDirectory: endOfCentralDirectory.offsetOfCentralDirectory + endOfCentralDirectory.centralDirectorySize,
                totalNumberOfDisks: 1
            )
            try writeZip64EndOfCentralLocator(zip64EndOfCentralLocator)
        }

        try self.storage.writeIntegers(
            Zip.endOfCentralDirectorySignature,
            diskNumber16,
            diskNumberCentralDirectoryStarts16,
            diskEntries16,
            totalEntries16,
            centralDirectorySize32,
            offsetOfCentralDirectory32,
            UInt16(endOfCentralDirectory.comment.utf8.count)
        )
        try self.storage.writeString(endOfCentralDirectory.comment)
    }
}
