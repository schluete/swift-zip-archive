/// Zip file types
/// Details on these can be found in the PKZIP AppNotes https://support.pkware.com/pkzip/application-note-archives
public enum Zip {
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
        let extraFields: [ExtraField]
        let _fileModificationTime: UInt16
        let _fileModificationDate: UInt16
        let crc32: UInt32
        let compressedSize: Int64
        let diskStart: UInt32
        let internalAttribute: UInt16
        let offsetOfLocalHeader: Int64

        internal init(
            flags: Zip.FileFlags,
            compressionMethod: Zip.FileCompressionMethod,
            fileModificationTime: UInt16,
            fileModificationDate: UInt16,
            crc32: UInt32,
            compressedSize: Int64,
            uncompressedSize: Int64,
            filename: String,
            extraFields: [ExtraField],
            comment: String,
            diskStart: UInt32,
            internalAttribute: UInt16,
            externalAttributes: UInt32,
            offsetOfLocalHeader: Int64
        ) {
            self.flags = flags
            self.compressionMethod = compressionMethod
            self._fileModificationTime = fileModificationTime
            self._fileModificationDate = fileModificationDate
            self.crc32 = crc32
            self.compressedSize = compressedSize
            self.uncompressedSize = uncompressedSize
            self.filename = filename
            self.extraFields = extraFields
            self.comment = comment
            self.diskStart = diskStart
            self.internalAttribute = internalAttribute
            self.externalAttributes = externalAttributes
            self.offsetOfLocalHeader = offsetOfLocalHeader
        }
    }

    public struct FileHeader32 {
        public let flags: FileFlags
        public let compressionMethod: FileCompressionMethod
        public let uncompressedSize: Int32
        public let filename: String
        public let comment: String
        public let externalAttributes: UInt32
        let extraFields: [ExtraField]
        let _fileModificationTime: UInt16
        let _fileModificationDate: UInt16
        let crc32: UInt32
        let compressedSize: Int32
        let diskStart: UInt16
        let internalAttribute: UInt16
        let offsetOfLocalHeader: Int32
    }

    public struct ExtraField {
        let header: UInt16
        let data: ArraySlice<UInt8>
    }

    enum ExtraFieldHeader: UInt16 {
        case zip64 = 1
    }

    struct Zip64ExtendedInformationExtraField {
        let uncompressedSize: Int64
        let compressedSize: Int64
        let offsetOfLocalHeader: Int64
        let diskStart: UInt32
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
        let extraFields: [ExtraField]
    }

    struct LocalFileHeader32 {
        let flags: FileFlags
        let compressionMethod: FileCompressionMethod
        let fileModificationTime: UInt16
        let fileModificationDate: UInt16
        let crc32: UInt32
        let compressedSize: Int32
        let uncompressedSize: Int32
        let filename: String
        let extraFields: [ExtraField]
    }

    struct Zip64EndOfCentralDirectory {
        //let versionMadeBy: UInt16
        //let versionNeeded: UInt16
        let diskNumber: UInt32
        let diskNumberCentralDirectoryStarts: UInt32
        let diskEntries: Int64
        let totalEntries: Int64
        let centralDirectorySize: Int64
        let offsetOfCentralDirectory: Int64
    }

    struct Zip64EndOfCentralLocator {
        let diskNumberCentralDirectoryStarts: UInt32
        let relativeOffsetEndOfCentralDirectory: Int64
        let totalNumberOfDisks: UInt32
    }

    struct EndOfCentralDirectory {
        let diskNumber: UInt32
        let diskNumberCentralDirectoryStarts: UInt32
        let diskEntries: Int64
        let totalEntries: Int64
        let centralDirectorySize: Int64
        let offsetOfCentralDirectory: Int64
        let comment: String
    }

    struct EndOfCentralDirectory32 {
        let diskNumber: UInt16
        let diskNumberCentralDirectoryStarts: UInt16
        let diskEntries: Int16
        let totalEntries: Int16
        let centralDirectorySize: Int32
        let offsetOfCentralDirectory: Int32
        let comment: String
    }

    static let localFileHeaderSignature = 0x0403_4b50
    static let fileHeaderSignature = 0x0201_4b50
    static let digitalSignatureSignature = 0x0505_4b50
    static let zip64EndOfCentralDirectorySignature = 0x0606_4b50
    static let zip64EndOfCentralLocatorSignature = 0x0706_4b50
    static let endOfCentralDirectorySignature = 0x0605_4b50
}
