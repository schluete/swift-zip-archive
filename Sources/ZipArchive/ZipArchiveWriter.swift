import CZipZlib
import SystemPackage

#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

/// Zip archive writer type
public final class ZipArchiveWriter<Storage: ZipWriteableStorage> {
    var storage: Storage
    var endOfCentralDirectoryRecord: Zip.EndOfCentralDirectory
    let directory: [Zip.FileHeader]
    let directoryBuffer: [UInt8]?
    var newDirectoryEntries: [Zip.FileHeader]

    public init() where Storage == ZipMemoryStorage<[UInt8]> {
        self.newDirectoryEntries = []
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
        self.directoryBuffer = nil
    }

    convenience public init(bytes: [UInt8]) throws where Storage == ZipMemoryStorage<[UInt8]> {
        try self.init(.init(bytes))
    }

    convenience public init(bytes: ArraySlice<UInt8>) throws where Storage == ZipMemoryStorage<ArraySlice<UInt8>> {
        try self.init(.init(bytes))
    }

    init(_ storage: Storage, appending: Bool = true) throws {
        self.newDirectoryEntries = []
        self.storage = storage
        if appending {
            let reader = try ZipArchiveReader(storage)
            self.endOfCentralDirectoryRecord = reader.endOfCentralDirectoryRecord
            // read directory before we truncate it
            try self.storage.seek(endOfCentralDirectoryRecord.offsetOfCentralDirectory)
            // Zip files support a central directory larger then 0xffff_ffff but we don't
            self.directoryBuffer = try self.storage.readBytes(length: numericCast(endOfCentralDirectoryRecord.centralDirectorySize))
            let memoryStorage = ZipMemoryStorage(self.directoryBuffer!)
            self.directory = try reader.readDirectory(memoryStorage)
            // truncate zip file
            try self.storage.truncate(endOfCentralDirectoryRecord.offsetOfCentralDirectory)
        } else {
            self.endOfCentralDirectoryRecord = .init(
                diskNumber: 0,
                diskNumberCentralDirectoryStarts: 0,
                diskEntries: 0,
                totalEntries: 0,
                centralDirectorySize: 0,
                offsetOfCentralDirectory: 0,
                comment: ""
            )
            self.directoryBuffer = nil
            self.directory = []
            // truncate zip file
            try self.storage.truncate(0)
        }
    }

    public func finalizeBuffer() throws -> Storage.Buffer where Storage: ZipMemoryStorage<[UInt8]> {
        try writeDirectory()
        return self.storage.buffer.buffer
    }

    public func finalizeBuffer() throws -> Storage.Buffer where Storage: ZipMemoryStorage<ArraySlice<UInt8>> {
        try writeDirectory()
        return self.storage.buffer.buffer
    }

    public func addFile(filename: String, contents: [UInt8]) throws {
        let filePath = FilePath(filename)
        let existingFileHeader =
            self.directory.first(where: { $0.filename == filePath.string })
            ?? self.newDirectoryEntries.first(where: { $0.filename == filePath.string })
        if let existingFileHeader {
            guard existingFileHeader.uncompressedSize == 0 else {
                throw ZipArchiveWriterError.fileAlreadyExists
            }
        }
        try addFolder(filePath.removingRoot().removingLastComponent())
        // Calculate CRC32
        let crc = crc32(0, bytes: contents)
        let currentOffest = try self.storage.seekOffset(0)
        let compressedContents = try ZlibDeflateCompressor(windowBits: 15).deflate(from: contents)
        let fileHeader = Zip.FileHeader(
            versionNeeded: 20,
            flags: [],
            compressionMethod: .deflated,
            fileModification: .now,
            crc32: crc,
            compressedSize: numericCast(compressedContents.count),
            uncompressedSize: numericCast(contents.count),
            filename: filename,
            extraFields: [],
            comment: "",
            diskStart: 0,
            internalAttribute: 0,
            externalAttributes: 0x8000_0000 | (0o644 << 16),  // regular file | permissions 644
            offsetOfLocalHeader: currentOffest
        )
        try writeLocalFileHeader(fileHeader)
        try storage.write(bytes: compressedContents)

        self.newDirectoryEntries.append(fileHeader)
    }

    func addFolder(_ filePath: FilePath) throws {
        #if os(Windows)
        let separator = "\\"
        #else
        let separator = "/"
        #endif
        let folderName = "\(filePath.string)\(separator)"
        guard !filePath.isEmpty else { return }
        let existingFileHeader =
            self.directory.first(where: { $0.filename == folderName })
            ?? self.newDirectoryEntries.first(where: { $0.filename == folderName })
        if let existingFileHeader {
            guard existingFileHeader.uncompressedSize == 0 else {
                throw ZipArchiveWriterError.fileAlreadyExists
            }
            return
        }
        let fileHeader = Zip.FileHeader(
            versionNeeded: 10,
            flags: [],
            compressionMethod: .noCompression,
            fileModification: .now,
            crc32: 0,
            compressedSize: 0,
            uncompressedSize: 0,
            filename: folderName,
            extraFields: [],
            comment: "",
            diskStart: 0,
            internalAttribute: 0,
            externalAttributes: 0x4000_0000 | (0o755 << 16) | 0x10,  // directory | permissions 755 | MS-DOS directory flag
            offsetOfLocalHeader: 0
        )
        try writeLocalFileHeader(fileHeader)

        self.newDirectoryEntries.append(fileHeader)

    }

    func writeDirectory() throws {
        let centralDirectoryOffset = try storage.seekOffset(0)

        // write original directory
        if let directoryBuffer {
            try storage.write(bytes: directoryBuffer)
        }
        // write new files to directory
        for file in newDirectoryEntries {
            try writeFileHeader(file)
        }
        let centralDirectoryEndOffset = try storage.seekOffset(0)

        endOfCentralDirectoryRecord.offsetOfCentralDirectory = centralDirectoryOffset
        endOfCentralDirectoryRecord.centralDirectorySize = centralDirectoryEndOffset - centralDirectoryOffset
        endOfCentralDirectoryRecord.diskEntries += numericCast(newDirectoryEntries.count)
        endOfCentralDirectoryRecord.totalEntries += numericCast(newDirectoryEntries.count)

        try writeEndOfCentralDirectory(endOfCentralDirectoryRecord)
    }

    func writeFileHeader(_ fileHeader: Zip.FileHeader) throws {
        var fileHeader = fileHeader
        let extraFieldsBuffer = getExtraFieldBuffer(&fileHeader, localFileHeader: false)
        let (fileModificationTime, fileModificationDate) = fileHeader.fileModification.msdosDate()
        try self.storage.writeIntegers(
            Zip.fileHeaderSignature,
            Zip.versionMadeBy,
            fileHeader.versionNeeded,
            fileHeader.flags.rawValue,
            fileHeader.compressionMethod.rawValue,
            fileModificationTime,
            fileModificationDate,
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
        let extraFields = getExtraFieldBuffer(&fileHeader, localFileHeader: true)

        let (fileModificationTime, fileModificationDate) = fileHeader.fileModification.msdosDate()
        try self.storage.writeIntegers(
            Zip.localFileHeaderSignature,
            fileHeader.versionNeeded,
            fileHeader.flags.rawValue,
            fileHeader.compressionMethod.rawValue,
            fileModificationTime,
            fileModificationDate,
            fileHeader.crc32,
            UInt32(fileHeader.compressedSize),
            UInt32(fileHeader.uncompressedSize),
            UInt16(fileHeader.filename.utf8.count),
            UInt16(extraFields.count)
        )
        try self.storage.writeString(fileHeader.filename)
        try self.storage.write(bytes: extraFields)
    }

    func getExtraFieldBuffer(_ fileHeader: inout Zip.FileHeader, localFileHeader: Bool) -> ArraySlice<UInt8> {
        // Extended timestamp extra field
        let extendedTimestampExtraFieldSize = localFileHeader ? 4 + 9 : 4 + 5
        // Zip64 extra field
        let compressedSize32 = fileHeader.compressedSize > 0xffff_ffff ? 0xffff_ffff : numericCast(fileHeader.compressedSize)
        let uncompressedSize32 = fileHeader.uncompressedSize > 0xffff_ffff ? 0xffff_ffff : numericCast(fileHeader.uncompressedSize)
        let offsetOfLocalHeader32 = fileHeader.offsetOfLocalHeader > 0xffff_ffff ? 0xffff_ffff : numericCast(fileHeader.offsetOfLocalHeader)

        let includeZip64 = compressedSize32 == 0xffff_ffff || uncompressedSize32 == 0xffff_ffff || offsetOfLocalHeader32 == 0xffff_ffff

        var zip64ExtraFieldSize: Int
        if includeZip64 {
            zip64ExtraFieldSize = 4
            if compressedSize32 == 0xffff_ffff { zip64ExtraFieldSize += 8 }
            if uncompressedSize32 == 0xffff_ffff { zip64ExtraFieldSize += 8 }
            if offsetOfLocalHeader32 == 0xffff_ffff { zip64ExtraFieldSize += 8 }
        } else {
            zip64ExtraFieldSize = 0
        }
        // extra field size is timestamp + zip64 sizes + size of all the other extra fields
        let extraFieldsSize = fileHeader.extraFields.reduce(
            extendedTimestampExtraFieldSize + zip64ExtraFieldSize
        ) { $0 + $1.data.count + 4 }

        var memoryBuffer = MemoryBuffer(size: extraFieldsSize)
        // write extended timestamp
        memoryBuffer.writeIntegers(
            Zip.ExtraFieldHeader.extendedTimestamp.rawValue,
            UInt16(extendedTimestampExtraFieldSize - 4),
            UInt8(3),
            Int32(fileHeader.fileModification.timeIntervalSince1970)
        )
        // local file header also includes
        if localFileHeader {
            memoryBuffer.writeInteger(Int32(fileHeader.fileModification.timeIntervalSince1970))
        }
        // write zip64
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
        /// Check the size of values to see whether we need a zip64 block
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

extension ZipArchiveWriter {
    public struct FileOptions: OptionSet {
        public let rawValue: Int

        public init(rawValue: Int) {
            self.rawValue = rawValue
        }

        public static var create: Self { .init(rawValue: (1 << 0)) }
    }
    public static func withFile(_ filename: String, options: FileOptions = [], process: (ZipArchiveWriter) throws -> Void) throws
    where Storage == ZipFileStorage {
        let fileDescriptor = try FileDescriptor.open(
            .init(filename),
            .readWrite,
            options: options.contains(.create) ? .create : [],
            permissions: options.contains(.create) ? [.ownerReadWrite, .groupRead, .otherRead] : nil
        )
        return try fileDescriptor.closeAfter {
            let writer = try ZipArchiveWriter<ZipFileStorage>(
                ZipFileStorage(fileDescriptor),
                appending: !options.contains(.create)
            )
            try process(writer)
            try writer.writeDirectory()
        }
    }

    public static func withFile(
        _ filename: String,
        options: FileOptions = [],
        isolation: isolated (any Actor)? = #isolation,
        process: (ZipArchiveWriter) async throws -> Void
    ) async throws
    where Storage == ZipFileStorage {
        let fileDescriptor = try FileDescriptor.open(
            .init(filename),
            .readWrite,
            options: options.contains(.create) ? .create : [],
            permissions: options.contains(.create) ? [.ownerReadWrite, .groupRead, .otherRead] : nil
        )
        return try await fileDescriptor.closeAfter {
            let writer = try ZipArchiveWriter<ZipFileStorage>(
                ZipFileStorage(fileDescriptor),
                appending: !options.contains(.create)
            )
            try await process(writer)
            try writer.writeDirectory()
        }
    }
}

public struct ZipArchiveWriterError: Error {
    internal enum Value {
        case fileAlreadyExists
    }
    internal let value: Value

    public static var fileAlreadyExists: Self { .init(value: .fileAlreadyExists) }
}
