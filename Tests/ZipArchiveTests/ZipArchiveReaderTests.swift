import Foundation
import Testing

@testable import ZipArchive

struct ZipArchiveReaderTests {
    @Test func testMSDOSDateAndBack() async throws {
        let msdosDate = 3 | (6 << 5) | (24 << 9)
        let msdosTime = 21 | (45 << 5) | (19 << 11)
        let date = Date(msdosTime: UInt16(msdosTime), msdosDate: UInt16(msdosDate))
        let (msdosTime2, msdosDate2) = date.msdosDate()
        #expect(msdosTime == msdosTime2)
        #expect(msdosDate == msdosDate2)
    }
    @Test
    func loadZipDirectoryFromMemory() throws {
        let filePath = Bundle.module.path(forResource: "source", ofType: "zip")!
        let fileHandle = FileHandle(forReadingAtPath: filePath)
        let data = try #require(try fileHandle?.readToEnd())
        let zipArchiveReader = try ZipArchiveReader(ZipMemoryStorage(data))
        let zipArchiveDirectory = try zipArchiveReader.readDirectory()
        #expect(zipArchiveDirectory.count == 9)
        #expect(zipArchiveDirectory[0].filename == "Sources/Zip/")
        #expect(zipArchiveDirectory[8].filename == "Tests/ZipTests/ZipFileReaderTests.swift")
    }

    @Test
    func loadZipArchiveFromMemory() throws {
        let filePath = Bundle.module.path(forResource: "source", ofType: "zip")!
        let fileHandle = FileHandle(forReadingAtPath: filePath)
        let data = try #require(try fileHandle?.readToEnd())
        let ZipArchiveReader = try ZipArchiveReader(ZipMemoryStorage(data))
        let zipArchiveDirectory = try ZipArchiveReader.readDirectory()
        _ = try ZipArchiveReader.readFile(zipArchiveDirectory[2])
    }

    @Test
    func loadZipDirectory() throws {
        let filePath = Bundle.module.path(forResource: "source", ofType: "zip")!
        try ZipArchiveReader.withFile(filePath) { zipArchiveReader in
            let zipArchiveDirectory = try zipArchiveReader.readDirectory()
            #expect(zipArchiveDirectory.count == 9)
            #expect(zipArchiveDirectory[0].filename == "Sources/Zip/")
            #expect(zipArchiveDirectory[8].filename == "Tests/ZipTests/ZipFileReaderTests.swift")
        }
    }

    @Test
    func loadZipArchive() throws {
        let filePath = Bundle.module.path(forResource: "source", ofType: "zip")!
        try ZipArchiveReader.withFile(filePath) { zipArchiveReader in
            let zipArchiveDirectory = try zipArchiveReader.readDirectory()
            let packageSwiftRecord = try #require(zipArchiveDirectory.first { $0.filename == "Sources/Zip/MemoryFileStorage.swift" })
            let file = try zipArchiveReader.readFile(packageSwiftRecord)
            #expect(String(decoding: file[...26], as: UTF8.self) == "public final class ZipFileM")
        }
    }

    @Test
    func loadEncryptedZipArchive() throws {
        let filePath = Bundle.module.path(forResource: "encrypted", ofType: "zip")!
        try ZipArchiveReader.withFile(filePath) { zipArchiveReader in
            let zipArchiveDirectory = try zipArchiveReader.readDirectory()
            let packageSwiftRecord = try #require(zipArchiveDirectory.first { $0.filename == "Sources/ZipArchive/ZipArchiveReader.swift" })
            let file = try zipArchiveReader.readFile(packageSwiftRecord, password: "testing123")
            #expect(String(decoding: file[...14], as: UTF8.self) == "import CZipZlib")
        }
    }

    @Test
    func loadZip64File() throws {
        let filePath = Bundle.module.path(forResource: "hello64", ofType: "zip")!
        try ZipArchiveReader.withFile(filePath) { zipArchiveReader in
            let ZipArchiveDirectory = try zipArchiveReader.readDirectory()
            let file = try zipArchiveReader.readFile(ZipArchiveDirectory[0])
            #expect(ZipArchiveDirectory[0].filename == "-")
            #expect(String(decoding: file, as: UTF8.self) == "Hello, world!\n")
        }
    }
}
