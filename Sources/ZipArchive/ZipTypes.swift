#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

/// Zip file types
/// Details on these can be found in the PKZIP AppNotes https://support.pkware.com/pkzip/application-note-archives
public enum Zip {
    #if os(Linux)
    static let versionMadeBy: UInt16 = 0x301
    #elseif os(Windows)
    static let versionMadeBy: UInt16 = 0x1
    #else
    static let versionMadeBy: UInt16 = 0x1301
    #endif

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
        //let versionMadeBy: UInt16
        var versionNeeded: UInt16
        public var flags: FileFlags
        public var compressionMethod: FileCompressionMethod
        var fileModification: Date
        var crc32: UInt32
        var compressedSize: Int64
        public var uncompressedSize: Int64
        public var filename: String
        var extraFields: [ExtraField]
        public var comment: String
        var diskStart: UInt32
        var internalAttribute: UInt16
        public var externalAttributes: UInt32
        var offsetOfLocalHeader: Int64
    }

    public struct ExtraField {
        let header: ExtraFieldHeader
        let data: ArraySlice<UInt8>
    }

    struct ExtraFieldHeader: RawRepresentable, Equatable {
        let rawValue: UInt16
        static var zip64: Self { .init(rawValue: 1) }
        static var extendedTimestamp: Self { .init(rawValue: 0x5455) }
    }

    struct Zip64ExtendedInformationExtraField {
        let uncompressedSize: Int64
        let compressedSize: Int64
        let offsetOfLocalHeader: Int64
        let diskStart: UInt32
    }

    struct LocalFileHeader {
        //let versionMadeBy: UInt16
        var versionNeeded: UInt16
        var flags: FileFlags
        var compressionMethod: FileCompressionMethod
        var fileModification: Date
        var crc32: UInt32
        var compressedSize: Int64
        var uncompressedSize: Int64
        var filename: String
        var extraFields: [ExtraField]
    }

    struct Zip64EndOfCentralDirectory {
        //let versionMadeBy: UInt16
        let versionNeeded: UInt16
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
        var diskNumber: UInt32
        var diskNumberCentralDirectoryStarts: UInt32
        var diskEntries: Int64
        var totalEntries: Int64
        var centralDirectorySize: Int64
        var offsetOfCentralDirectory: Int64
        var comment: String
    }

    static let localFileHeaderSignature: UInt32 = 0x0403_4b50
    static let fileHeaderSignature: UInt32 = 0x0201_4b50
    static let digitalSignatureSignature: UInt32 = 0x0505_4b50
    static let zip64EndOfCentralDirectorySignature: UInt32 = 0x0606_4b50
    static let zip64EndOfCentralLocatorSignature: UInt32 = 0x0706_4b50
    static let endOfCentralDirectorySignature: UInt32 = 0x0605_4b50
}
