import CZipZlib

/// Zip file reader type
public class ZipFileReader<Storage: ZipReadableStorage> {
    let file: Storage
    let endOfCentralDirectory: Zip.EndOfCentralDirectory
    let compressionMethods: ZipCompressionMethodsMap

    public init(_ file: Storage) async throws {
        self.file = file
        self.endOfCentralDirectory = try await Self.readEndOfCentralDirectory(file: file)
        self.compressionMethods = [
            Zip.FileCompressionMethod.noCompression: DoNothingCompressor(),
            Zip.FileCompressionMethod.deflated: ZlibDeflateCompressor(windowBits: 9),
        ]
    }

    /// Read directory from zip file
    public func readDirectory() async throws -> [Zip.FileHeader] {
        var directory: [Zip.FileHeader] = []
        try await file.seek(numericCast(endOfCentralDirectory.offsetOfCentralDirectory))
        for _ in 0..<endOfCentralDirectory.diskEntries {
            let fileHeader = try await self.readFileHeader()
            directory.append(fileHeader)
        }
        return directory
    }

    /// Read file from zip file
    public func readFile(_ file: Zip.FileHeader) async throws -> [UInt8] {
        try await self.file.seek(numericCast(file.offsetOfLocalHeader))
        let localFileHeader = try await readLocalFileHeader()
        guard localFileHeader.filename == file.filename else { throw ZipFileReaderError.invalidFileHeader }
        guard let compressor = self.compressionMethods[localFileHeader.compressionMethod] else {
            throw ZipFileReaderError.unsupportedCompressionMethod
        }
        // Read bytes and uncompress
        let fileBytes = try await self.file.readBytes(length: numericCast(localFileHeader.compressedSize))
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
            throw ZipFileReaderError.crc32FileValidationFailed
        }
        return uncompressedBytes
    }

    func readLocalFileHeader() async throws -> Zip.LocalFileHeader {
        let (
            signature, _, flags, compression, modTime, modDate, crc32, compressedSize, uncompressedSize, fileNameLength, extraFieldsLength
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
        let extraFieldsBuffer = try await file.readBytes(length: numericCast(extraFieldsLength))
        let extraFields = try readExtraFields(extraFieldsBuffer)

        /// Extract ZIP64 extra field
        var uncompressedSize64: UInt64 = numericCast(uncompressedSize)
        var compressedSize64: UInt64 = numericCast(compressedSize)
        if let zip64ExtraField = extraFields.first { $0.header == Zip.ExtraFieldHeader.zip64.rawValue } {
            var memoryBuffer = MemoryBuffer(zip64ExtraField.data)
            if uncompressedSize == 0xffff_ffff {
                uncompressedSize64 = try memoryBuffer.readInteger(as: UInt64.self)
            }
            if compressedSize == 0xffff_ffff {
                compressedSize64 = try memoryBuffer.readInteger(as: UInt64.self)
            }
        }
        guard let compressionMethod = Zip.FileCompressionMethod(rawValue: compression) else { throw ZipFileReaderError.invalidFileHeader }
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

    func readFileHeader() async throws -> Zip.FileHeader {
        let (
            signature, _, _, flags, compression, modTime, modDate, crc32, compressedSize, uncompressedSize, fileNameLength,
            extraFieldsLength, commentLength, diskStart, internalAttribute, externalAttribute, offsetOfLocalHeader
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
        let extraFieldsBuffer = try await file.readBytes(length: numericCast(extraFieldsLength))
        let comment = try await file.readString(length: numericCast(commentLength))

        let extraFields = try readExtraFields(extraFieldsBuffer)

        /// Extract ZIP64 extra field
        var uncompressedSize64: UInt64 = numericCast(uncompressedSize)
        var compressedSize64: UInt64 = numericCast(compressedSize)
        var offsetOfLocalHeader64: UInt64 = numericCast(offsetOfLocalHeader)
        var diskStart32: UInt32 = numericCast(diskStart)
        if let zip64ExtraField = extraFields.first { $0.header == Zip.ExtraFieldHeader.zip64.rawValue } {
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
        guard let compressionMethod = Zip.FileCompressionMethod(rawValue: compression) else { throw ZipFileReaderError.invalidFileHeader }
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

    static func readEndOfCentralDirectory(file: some ZipReadableStorage) async throws -> Zip.EndOfCentralDirectory {
        try await searchForEndOfCentralDirectory(file: file)
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

    static func searchForEndOfCentralDirectory(file: some ZipReadableStorage) async throws {
        let fileChunkLength = 1024
        let fileSize = try file.length

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

}

public struct ZipFileReaderError: Error {
    internal enum Value {
        case invalidFileHeader
        case failedToFindCentralDirectory
        case internalError
        case compressionError
        case unsupportedCompressionMethod
        case failedToReadFromBuffer
        case crc32FileValidationFailed
    }
    internal let value: Value

    public static var invalidFileHeader: Self { .init(value: .invalidFileHeader) }
    public static var failedToFindCentralDirectory: Self { .init(value: .failedToFindCentralDirectory) }
    public static var internalError: Self { .init(value: .internalError) }
    public static var compressionError: Self { .init(value: .compressionError) }
    public static var unsupportedCompressionMethod: Self { .init(value: .unsupportedCompressionMethod) }
    public static var failedToReadFromBuffer: Self { .init(value: .failedToReadFromBuffer) }
    public static var crc32FileValidationFailed: Self { .init(value: .crc32FileValidationFailed) }
}
