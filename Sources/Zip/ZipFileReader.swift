import Foundation

public class ZipFileReader<Storage: ZipReadableFileStorage> {
    var file: Storage
    let directory: [FileHeader]

    public init(_ file: Storage) async throws {
        self.file = file

        try await Self.searchForEndOfCentralDirectory(file: file)
        let endOfCentralDirectory = try await Self.readEndOfCentralDirectory(file: file)
        self.directory = try await Self.readDirectory(file: file, endOfCentralDirectory: endOfCentralDirectory)
    }

    static func readLocalFileHeader(file: some ZipReadableFileStorage) async throws -> LocalFileHeader {
        let (
            signature, _, flags, compression, modTime, modDate, crc32, compressedSize, uncompressedSize, fileNameLength, extraFieldLength
        ) =
            try await file.readIntegers(
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
        guard signature == 0x0403_4b50 else { throw ZipFileReaderError.invalidFileHeader }

        let filename = try await file.readString(length: numericCast(fileNameLength))
        let extraField = try await file.readBytes(length: numericCast(extraFieldLength))

        guard let compressionMethod = FileCompressionMethod(rawValue: compression) else { throw ZipFileReaderError.invalidFileHeader }
        return .init(
            flags: .init(rawValue: flags),
            compressionMethod: compressionMethod,
            fileModificationTime: .now,
            crc32: crc32,
            compressedSize: numericCast(compressedSize),
            uncompressedSize: numericCast(uncompressedSize),
            filename: filename
        )
    }

    static func readFileHeader(file: some ZipReadableFileStorage) async throws -> FileHeader {
        let (
            signature, _, _, flags, compression, modTime, modDate, crc32, compressedSize, uncompressedSize, fileNameLength,
            extraFieldLength,
            commentLength, diskStart, internalAttribute, externalAttribute, offsetOfLocalHeader
        ) =
            try await file.readIntegers(
                UInt32.self,
                UInt16.self,
                UInt16.self,
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
        guard signature == 0x0201_4b50 else { throw ZipFileReaderError.invalidFileHeader }

        let filename = try await file.readString(length: numericCast(fileNameLength))
        let extraField = try await file.readBytes(length: numericCast(extraFieldLength))
        let comment = try await file.readString(length: numericCast(commentLength))

        guard let compressionMethod = FileCompressionMethod(rawValue: compression) else { throw ZipFileReaderError.invalidFileHeader }
        return .init(
            flags: .init(rawValue: flags),
            compressionMethod: compressionMethod,
            fileModificationTime: .now,
            crc32: crc32,
            compressedSize: numericCast(compressedSize),
            uncompressedSize: numericCast(uncompressedSize),
            filename: filename,
            comment: comment,
            diskStart: diskStart,
            internalAttribute: internalAttribute,
            externalAttributes: externalAttribute,
            offsetOfLocalHeader: offsetOfLocalHeader
        )
    }

    static func readDirectory(file: some ZipReadableFileStorage, endOfCentralDirectory: EndOfCentralDirectory) async throws -> [FileHeader] {
        var directory: [FileHeader] = []
        try await file.seek(numericCast(endOfCentralDirectory.offsetOfCentralDirectory))
        for _ in 0..<endOfCentralDirectory.diskEntries {
            let fileHeader = try await Self.readFileHeader(file: file)
            directory.append(fileHeader)
        }
        return directory
    }

    static func readEndOfCentralDirectory(file: some ZipReadableFileStorage) async throws -> EndOfCentralDirectory {
        let (
            signature, diskNumber, diskNumberCentralDirectoryStarts, diskEntries, totalEntries, centralDirectorySize, offsetOfCentralDirectory,
            commentLength
        ) = try await file.readIntegers(
            UInt32.self,
            UInt16.self,
            UInt16.self,
            UInt16.self,
            UInt16.self,
            UInt32.self,
            UInt32.self,
            UInt16.self
        )
        guard signature == 0x0605_4b50 else { throw ZipFileReaderError.internalError }

        return .init(
            diskNumber: diskNumber,
            diskNumberCentralDirectoryStarts: diskNumberCentralDirectoryStarts,
            diskEntries: diskEntries,
            totalEntries: totalEntries,
            centralDirectorySize: centralDirectorySize,
            offsetOfCentralDirectory: offsetOfCentralDirectory,
            comment: try await file.readString(length: numericCast(commentLength))
        )
    }

    static func searchForEndOfCentralDirectory(file: some ZipReadableFileStorage) async throws {
        let fileChunkLength = 1024
        let fileSize = await file.length

        var filePosition = fileSize - 18

        while filePosition > 0 {
            let readSize = min(filePosition, fileChunkLength)
            filePosition -= readSize
            try await file.seek(filePosition)
            let bytes = try await file.read(readSize)
            for index in (bytes.startIndex..<bytes.index(bytes.endIndex, offsetBy: -3)).reversed() {
                if bytes[index] == 0x50, bytes[index + 1] == 0x4b, bytes[index + 2] == 0x5, bytes[index + 3] == 0x6 {
                    try await file.seekOffset(index - bytes.startIndex - readSize)
                    return
                }
            }
        }

        throw ZipFileReaderError.failedToFindCentralDirectory
    }

    struct FileFlags: OptionSet {
        let rawValue: UInt16

        static var encrypted: Self { .init(rawValue: 1 << 0) }
        static var compressionOption1: Self { .init(rawValue: 1 << 1) }
        static var compressionOption2: Self { .init(rawValue: 1 << 2) }
        static var dataDescriptor: Self { .init(rawValue: 1 << 3) }
        static var enhancedDeflation: Self { .init(rawValue: 1 << 4) }
        static var compressedPatchedData: Self { .init(rawValue: 1 << 5) }
        static var strongEncryption: Self { .init(rawValue: 1 << 6) }
        static var languageEncoding: Self { .init(rawValue: 1 << 11) }
        static var reserved1: Self { .init(rawValue: 1 << 12) }
        static var maskHeaderValues: Self { .init(rawValue: 1 << 13) }
        static var reserved2: Self { .init(rawValue: 1 << 14) }
        static var reserved3: Self { .init(rawValue: 1 << 15) }

    }
    enum FileCompressionMethod: UInt16 {
        case noCompression = 0
        case shrunk = 1
        case compressionFactor1 = 2
        case compressionFactor2 = 3
        case compressionFactor3 = 4
        case compressionFactor4 = 5
        case imploded = 6
        case reserved1 = 7
        case deflated = 8
        case enhancedDeflated = 9
        case pkWareDCLImploded = 10
        case reserved2 = 11
        case bZip2 = 12
        case reserved3 = 13
        case lzma = 14
        case reserved4 = 15
        case reserved5 = 16
        case reserved6 = 17
        case ibmTerse = 18
        case ibmLZ77 = 19
        case ppmd = 98
    }
    struct LocalFileHeader {
        let flags: FileFlags
        let compressionMethod: FileCompressionMethod
        let fileModificationTime: Date
        let crc32: UInt32
        let compressedSize: Int64
        let uncompressedSize: Int64
        let filename: String
    }

    struct FileHeader {
        let flags: FileFlags
        let compressionMethod: FileCompressionMethod
        let fileModificationTime: Date
        let crc32: UInt32
        let compressedSize: Int64
        let uncompressedSize: Int64
        let filename: String
        let comment: String
        let diskStart: UInt16
        let internalAttribute: UInt16
        let externalAttributes: UInt32
        let offsetOfLocalHeader: UInt32
    }

    struct EndOfCentralDirectory {
        let diskNumber: UInt16
        let diskNumberCentralDirectoryStarts: UInt16
        let diskEntries: UInt16
        let totalEntries: UInt16
        let centralDirectorySize: UInt32
        let offsetOfCentralDirectory: UInt32
        let comment: String
    }
}

public struct ZipFileReaderError: Error {
    internal enum Value {
        case invalidFileHeader
        case failedToFindCentralDirectory
        case internalError
    }
    internal let value: Value

    public static var invalidFileHeader: Self { .init(value: .invalidFileHeader) }
    public static var failedToFindCentralDirectory: Self { .init(value: .failedToFindCentralDirectory) }
    public static var internalError: Self { .init(value: .internalError) }
}
