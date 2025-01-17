import Foundation
import Testing

@testable import ZipArchive

struct ZipArchiveReaderTests {
    @Test
    func loadZipDirectoryFromMemory() throws {
        let filePath = Bundle.module.path(forResource: "source", ofType: "zip")!
        let fileHandle = FileHandle(forReadingAtPath: filePath)
        let data = try #require(try fileHandle?.readToEnd())
        let ZipArchiveReader = try ZipArchiveReader(ZipMemoryStorage(data))
        let ZipArchiveDirectory = try ZipArchiveReader.readDirectory()
        #expect(ZipArchiveDirectory.count == 9)
        #expect(ZipArchiveDirectory[0].filename == "Sources/Zip/")
        #expect(ZipArchiveDirectory[8].filename == "Tests/ZipTests/ZipFileReaderTests.swift")
    }

    @Test
    func loadZipArchiveFromMemory() throws {
        let filePath = Bundle.module.path(forResource: "source", ofType: "zip")!
        let fileHandle = FileHandle(forReadingAtPath: filePath)
        let data = try #require(try fileHandle?.readToEnd())
        let ZipArchiveReader = try ZipArchiveReader(ZipMemoryStorage(data))
        let ZipArchiveDirectory = try ZipArchiveReader.readDirectory()
        print("Loading \(ZipArchiveDirectory[2].filename)")
        let file = try ZipArchiveReader.readFile(ZipArchiveDirectory[2])
    }

    @Test
    func loadZipDirectory() throws {
        let filePath = Bundle.module.path(forResource: "source", ofType: "zip")!
        try ZipArchiveReader.withFile(filePath) { zipArchiveReader in
            let ZipArchiveDirectory = try zipArchiveReader.readDirectory()
            #expect(ZipArchiveDirectory.count == 9)
            #expect(ZipArchiveDirectory[0].filename == "Sources/Zip/")
            #expect(ZipArchiveDirectory[8].filename == "Tests/ZipTests/ZipFileReaderTests.swift")
        }
    }

    @Test
    func loadZipArchive() throws {
        let filePath = Bundle.module.path(forResource: "source", ofType: "zip")!
        try ZipArchiveReader.withFile(filePath) { zipArchiveReader in
            let ZipArchiveDirectory = try zipArchiveReader.readDirectory()
            let file = try zipArchiveReader.readFile(ZipArchiveDirectory[2])
            print(String(decoding: file, as: UTF8.self))
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
