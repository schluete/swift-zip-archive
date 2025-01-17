import CZipZlib

/// Zip file reader type
public final class ZipArchiveReader<Storage: ZipReadableStorage> {
    let file: Storage
    let endOfCentralDirectory: Zip.EndOfCentralDirectory
    let compressionMethods: ZipCompressionMethodsMap

    init(_ file: Storage) throws {
        self.file = file
        self.endOfCentralDirectory = try Self.readEndOfCentralDirectory(file: file)
        self.compressionMethods = [
            Zip.FileCompressionMethod.noCompression: DoNothingCompressor(),
            Zip.FileCompressionMethod.deflated: ZlibDeflateCompressor(windowBits: 15),
        ]
    }

    convenience public init<Bytes: RangeReplaceableCollection>(bytes: Bytes) throws
    where Bytes.Element == UInt8, Bytes.Index == Int, Storage == ZipMemoryStorage<Bytes> {
        try self.init(ZipMemoryStorage(bytes))
    }

    /// Read directory from zip file
    public func readDirectory() throws -> [Zip.FileHeader] {
        var directory: [Zip.FileHeader] = []
        try file.seek(numericCast(endOfCentralDirectory.offsetOfCentralDirectory))
        let bytes = try file.readBytes(length: numericCast(endOfCentralDirectory.centralDirectorySize))
        let memoryStorage = ZipMemoryStorage(bytes)
        for _ in 0..<endOfCentralDirectory.diskEntries {
            let fileHeader = try self.readFileHeader(from: memoryStorage)
            directory.append(fileHeader)
        }
        return directory
    }

    /// Read file from zip file
    public func readFile(_ file: Zip.FileHeader) throws -> [UInt8] {
        try self.file.seek(numericCast(file.offsetOfLocalHeader))
        let localFileHeader = try readLocalFileHeader()
        guard localFileHeader.filename == file.filename else { throw ZipArchiveReaderError.invalidFileHeader }
        guard let compressor = self.compressionMethods[localFileHeader.compressionMethod] else {
            throw ZipArchiveReaderError.unsupportedCompressionMethod
        }
        // Read bytes and uncompress
        let fileBytes = try self.file.readBytes(length: numericCast(localFileHeader.compressedSize))
        let uncompressedBytes = try compressor.inflate(from: fileBytes, uncompressedSize: numericCast(localFileHeader.uncompressedSize))
        // Verify CRC32
        let crc = uncompressedBytes.withUnsafeBytes { bytes in
            var crc = crc32(0xffff_ffff, nil, 0)
            crc = crc32(crc, bytes.baseAddress, numericCast(bytes.count))
            return crc
        }
        guard crc == localFileHeader.crc32 else {
            print(crc)
            print(localFileHeader.crc32)
            throw ZipArchiveReaderError.crc32FileValidationFailed
        }
        return uncompressedBytes
    }

    func readLocalFileHeader() throws -> Zip.LocalFileHeader {
        let (
            signature, _, flags, compression, modTime, modDate, crc32, compressedSize, uncompressedSize, fileNameLength, extraFieldsLength
        ) =
            try file.readIntegers(
                UInt32.self,
                UInt16.self,
                UInt16.self,
                UInt16.self,
                UInt16.self,
                UInt16.self,
                UInt32.self,
                UInt32.self,
                UInt32.self,
                UInt16.self,
                UInt16.self
            )
        guard signature == Zip.localFileHeaderSignature else { throw ZipArchiveReaderError.invalidFileHeader }
        let filename = try file.readString(length: numericCast(fileNameLength))
        let extraFieldsBuffer = try file.readBytes(length: numericCast(extraFieldsLength))
        let extraFields = try readExtraFields(extraFieldsBuffer)

        /// Extract ZIP64 extra field
        var uncompressedSize64: UInt64 = numericCast(uncompressedSize)
        var compressedSize64: UInt64 = numericCast(compressedSize)
        if let zip64ExtraField = extraFields.first(where: { $0.header == Zip.ExtraFieldHeader.zip64.rawValue }) {
            var memoryBuffer = MemoryBuffer(zip64ExtraField.data)
            if uncompressedSize == 0xffff_ffff {
                uncompressedSize64 = try memoryBuffer.readInteger(as: UInt64.self)
            }
            if compressedSize == 0xffff_ffff {
                compressedSize64 = try memoryBuffer.readInteger(as: UInt64.self)
            }
        }
        guard let compressionMethod = Zip.FileCompressionMethod(rawValue: compression) else { throw ZipArchiveReaderError.invalidFileHeader }
        return .init(
            flags: .init(rawValue: flags),
            compressionMethod: compressionMethod,
            fileModificationTime: modTime,
            fileModificationDate: modDate,
            crc32: crc32,
            compressedSize: compressedSize64,
            uncompressedSize: uncompressedSize64,
            filename: filename,
            extraFields: extraFields
        )
    }

    func readFileHeader(from storage: some ZipReadableStorage) throws -> Zip.FileHeader {
        let (
            signature, _, flags, compression, modTime, modDate, crc32, compressedSize, uncompressedSize, fileNameLength,
            extraFieldsLength, commentLength, diskStart, internalAttribute, externalAttribute, offsetOfLocalHeader
        ) =
            try storage.readIntegers(
                UInt32.self,
                UInt32.self,
                UInt16.self,
                UInt16.self,
                UInt16.self,
                UInt16.self,
                UInt32.self,
                UInt32.self,
                UInt32.self,
                UInt16.self,
                UInt16.self,
                UInt16.self,
                UInt16.self,
                UInt16.self,
                UInt32.self,
                UInt32.self
            )
        guard signature == Zip.fileHeaderSignature else { throw ZipArchiveReaderError.invalidFileHeader }

        let filename = try storage.readString(length: numericCast(fileNameLength))
        let extraFieldsBuffer = try storage.readBytes(length: numericCast(extraFieldsLength))
        let comment = try storage.readString(length: numericCast(commentLength))

        let extraFields = try readExtraFields(extraFieldsBuffer)

        /// Extract ZIP64 extra field
        var uncompressedSize64: UInt64 = numericCast(uncompressedSize)
        var compressedSize64: UInt64 = numericCast(compressedSize)
        var offsetOfLocalHeader64: UInt64 = numericCast(offsetOfLocalHeader)
        var diskStart32: UInt32 = numericCast(diskStart)
        if let zip64ExtraField = extraFields.first(where: { $0.header == Zip.ExtraFieldHeader.zip64.rawValue }) {
            var memoryBuffer = MemoryBuffer(zip64ExtraField.data)
            if uncompressedSize == 0xffff_ffff {
                uncompressedSize64 = try memoryBuffer.readInteger(as: UInt64.self)
            }
            if compressedSize == 0xffff_ffff {
                compressedSize64 = try memoryBuffer.readInteger(as: UInt64.self)
            }
            if offsetOfLocalHeader == 0xffff_ffff {
                offsetOfLocalHeader64 = try memoryBuffer.readInteger(as: UInt64.self)
            }
            if diskStart == 0xffff {
                diskStart32 = try memoryBuffer.readInteger(as: UInt32.self)
            }
        }
        guard let compressionMethod = Zip.FileCompressionMethod(rawValue: compression) else { throw ZipArchiveReaderError.invalidFileHeader }
        return .init(
            flags: .init(rawValue: flags),
            compressionMethod: compressionMethod,
            fileModificationTime: modTime,
            fileModificationDate: modDate,
            crc32: crc32,
            compressedSize: compressedSize64,
            uncompressedSize: uncompressedSize64,
            filename: filename,
            extraFields: extraFields,
            comment: comment,
            diskStart: diskStart32,
            internalAttribute: internalAttribute,
            externalAttributes: externalAttribute,
            offsetOfLocalHeader: offsetOfLocalHeader64
        )
    }

    func readExtraFields(_ buffer: [UInt8]) throws -> [Zip.ExtraField] {
        var extraFieldsBuffer = MemoryBuffer(buffer)
        var extraFields: [Zip.ExtraField] = []
        while extraFieldsBuffer.position < extraFieldsBuffer.length {
            let (header, size) = try extraFieldsBuffer.readIntegers(UInt16.self, UInt16.self)
            let data = try extraFieldsBuffer.read(numericCast(size))
            extraFields.append(.init(header: header, data: data))
        }
        return extraFields
    }

    static func readEndOfCentralDirectory(file: some ZipReadableStorage) throws -> Zip.EndOfCentralDirectory {
        _ = try searchForEndOfCentralDirectory(file: file)
        try file.seekOffset(-20)
        let zip64EndOfCentralLocator = try Self.readZip64EndOfCentralLocator(file: file)

        let (
            signature, diskNumber, diskNumberCentralDirectoryStarts, diskEntries, totalEntries, centralDirectorySize, offsetOfCentralDirectory,
            commentLength
        ) = try file.readIntegers(
            UInt32.self,
            UInt16.self,
            UInt16.self,
            UInt16.self,
            UInt16.self,
            UInt32.self,
            UInt32.self,
            UInt16.self
        )

        guard signature == Zip.endOfCentralDirectorySignature else { throw ZipArchiveReaderError.internalError }

        let comment = try file.readString(length: numericCast(commentLength))

        // Zip64
        var diskNumber32: UInt32 = numericCast(diskNumber)
        var diskEntries64: UInt64 = numericCast(diskEntries)
        var totalEntries64: UInt64 = numericCast(totalEntries)
        var centralDirectorySize64: UInt64 = numericCast(centralDirectorySize)
        var offsetOfCentralDirectory64: UInt64 = numericCast(offsetOfCentralDirectory)
        var diskNumberCentralDirectoryStarts32: UInt32 = numericCast(diskNumberCentralDirectoryStarts)
        if let zip64EndOfCentralLocator {
            if diskNumberCentralDirectoryStarts == 0xffff {
                diskNumberCentralDirectoryStarts32 = zip64EndOfCentralLocator.diskNumberCentralDirectoryStarts
            }
            // jump to zip64 central directory
            //let offset = zip64EndOfCentralLocator.relativeOffsetEndOfCentralDirectory
            try file.seek(numericCast(zip64EndOfCentralLocator.relativeOffsetEndOfCentralDirectory))
            let zip64EndOfCentralDirectory = try Self.readZip64EndOfCentralDirectory(file: file)
            if diskNumber == 0xffff {
                diskNumber32 = zip64EndOfCentralDirectory.diskNumber
            }
            if diskEntries == 0xffff {
                diskEntries64 = zip64EndOfCentralDirectory.diskEntries
            }
            if totalEntries == 0xffff {
                totalEntries64 = zip64EndOfCentralDirectory.totalEntries
            }
            if centralDirectorySize == 0xffff_ffff {
                centralDirectorySize64 = zip64EndOfCentralDirectory.centralDirectorySize
            }
            if offsetOfCentralDirectory == 0xffff_ffff {
                offsetOfCentralDirectory64 = zip64EndOfCentralDirectory.offsetOfCentralDirectory
            }
            // do stuff
        }
        return .init(
            diskNumber: diskNumber32,
            diskNumberCentralDirectoryStarts: diskNumberCentralDirectoryStarts32,
            diskEntries: diskEntries64,
            totalEntries: totalEntries64,
            centralDirectorySize: centralDirectorySize64,
            offsetOfCentralDirectory: offsetOfCentralDirectory64,
            comment: comment
        )
    }

    static func readZip64EndOfCentralLocator(file: some ZipReadableStorage) throws -> Zip.Zip64EndOfCentralLocator? {
        let (signature, diskNumberCentralDirectoryStarts, relativeOffsetEndOfCentralDirectory, totalNumberOfDisks) = try file.readIntegers(
            UInt32.self,
            UInt32.self,
            Int64.self,
            UInt32.self
        )
        guard signature == Zip.zip64EndOfCentralLocatorSignature else { return nil }
        return .init(
            diskNumberCentralDirectoryStarts: diskNumberCentralDirectoryStarts,
            relativeOffsetEndOfCentralDirectory: relativeOffsetEndOfCentralDirectory,
            totalNumberOfDisks: totalNumberOfDisks
        )
    }

    static func readZip64EndOfCentralDirectory(file: some ZipReadableStorage) throws -> Zip.Zip64EndOfCentralDirectory {
        let (signature, _, diskNumber, diskNumberCentralDirectoryStarts, diskEntries, totalEntries, centralDirectorySize, offsetOfCentralDirectory) =
            try file.readIntegers(
                UInt32.self,
                UInt32.self,
                UInt32.self,
                UInt32.self,
                UInt64.self,
                UInt64.self,
                UInt64.self,
                UInt64.self
            )
        guard signature == Zip.zip64EndOfCentralDirectorySignature else { throw ZipArchiveReaderError.invalidDirectory }
        return .init(
            diskNumber: diskNumber,
            diskNumberCentralDirectoryStarts: diskNumberCentralDirectoryStarts,
            diskEntries: diskEntries,
            totalEntries: totalEntries,
            centralDirectorySize: centralDirectorySize,
            offsetOfCentralDirectory: offsetOfCentralDirectory
        )
    }

    static func searchForEndOfCentralDirectory(file: some ZipReadableStorage) throws -> Int {
        let fileChunkLength = 1024
        let fileSize = try file.seekEnd(0)

        var filePosition = fileSize - 18

        while filePosition > 0, filePosition + 0xffff > fileSize {
            let readSize = min(filePosition, fileChunkLength)
            filePosition -= readSize
            try file.seek(filePosition)
            let bytes = try file.read(readSize)
            for index in (bytes.startIndex..<bytes.index(bytes.endIndex, offsetBy: -3)).reversed() {
                if bytes[index] == 0x50, bytes[index + 1] == 0x4b, bytes[index + 2] == 0x5, bytes[index + 3] == 0x6 {
                    let offset = try file.seekOffset(index - bytes.startIndex - readSize)
                    return numericCast(offset)
                }
            }
        }

        throw ZipArchiveReaderError.failedToFindCentralDirectory
    }

}

public struct ZipArchiveReaderError: Error {
    internal enum Value {
        case invalidFileHeader
        case invalidDirectory
        case failedToFindCentralDirectory
        case internalError
        case compressionError
        case unsupportedCompressionMethod
        case failedToReadFromBuffer
        case crc32FileValidationFailed
    }
    internal let value: Value

    public static var invalidFileHeader: Self { .init(value: .invalidFileHeader) }
    public static var invalidDirectory: Self { .init(value: .invalidDirectory) }
    public static var failedToFindCentralDirectory: Self { .init(value: .failedToFindCentralDirectory) }
    public static var internalError: Self { .init(value: .internalError) }
    public static var compressionError: Self { .init(value: .compressionError) }
    public static var unsupportedCompressionMethod: Self { .init(value: .unsupportedCompressionMethod) }
    public static var failedToReadFromBuffer: Self { .init(value: .failedToReadFromBuffer) }
    public static var crc32FileValidationFailed: Self { .init(value: .crc32FileValidationFailed) }
}
