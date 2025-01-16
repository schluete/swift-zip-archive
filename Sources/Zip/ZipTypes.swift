public enum ZipFile {
    public struct FileFlags: OptionSet {
        public let rawValue: UInt16

        public init(rawValue: UInt16) {
            self.rawValue = rawValue
        }

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
    public enum FileCompressionMethod: UInt16, Hashable {
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

    public struct FileHeader {
        public let flags: FileFlags
        public let compressionMethod: FileCompressionMethod
        public let uncompressedSize: Int64
        public let filename: String
        public let comment: String
        public let externalAttributes: UInt32
        let _fileModificationTime: UInt16
        let _fileModificationDate: UInt16
        let crc32: UInt32
        let compressedSize: Int64
        let diskStart: UInt16
        let internalAttribute: UInt16
        let offsetOfLocalHeader: UInt32

        internal init(
            flags: ZipFile.FileFlags,
            compressionMethod: ZipFile.FileCompressionMethod,
            fileModificationTime: UInt16,
            fileModificationDate: UInt16,
            crc32: UInt32,
            compressedSize: Int64,
            uncompressedSize: Int64,
            filename: String,
            comment: String,
            diskStart: UInt16,
            internalAttribute: UInt16,
            externalAttributes: UInt32,
            offsetOfLocalHeader: UInt32
        ) {
            self.flags = flags
            self.compressionMethod = compressionMethod
            self._fileModificationTime = fileModificationTime
            self._fileModificationDate = fileModificationDate
            self.crc32 = crc32
            self.compressedSize = compressedSize
            self.uncompressedSize = uncompressedSize
            self.filename = filename
            self.comment = comment
            self.diskStart = diskStart
            self.internalAttribute = internalAttribute
            self.externalAttributes = externalAttributes
            self.offsetOfLocalHeader = offsetOfLocalHeader
        }
    }

    struct LocalFileHeader {
        let flags: FileFlags
        let compressionMethod: FileCompressionMethod
        let fileModificationTime: UInt16
        let fileModificationDate: UInt16
        let crc32: UInt32
        let compressedSize: Int64
        let uncompressedSize: Int64
        let filename: String
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
