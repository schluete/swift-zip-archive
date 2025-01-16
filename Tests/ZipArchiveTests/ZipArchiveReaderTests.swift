import Foundation
import Testing

@testable import ZipArchive

struct ZipArchiveReaderTests {
    @Test
    func loadZipDirectoryFromMemory() async throws {
        let filePath = Bundle.module.path(forResource: "source", ofType: "zip")!
        let fileHandle = FileHandle(forReadingAtPath: filePath)
        let data = try #require(try fileHandle?.readToEnd())
        let ZipArchiveReader = try await ZipArchiveReader(ZipMemoryStorage(data))
        let ZipArchiveDirectory = try await ZipArchiveReader.readDirectory()
        #expect(ZipArchiveDirectory.count == 9)
        #expect(ZipArchiveDirectory[0].filename == "Sources/Zip/")
        #expect(ZipArchiveDirectory[8].filename == "Tests/ZipTests/ZipArchiveReaderTests.swift")
    }

    @Test
    func loadZipArchiveFromMemory() async throws {
        let filePath = Bundle.module.path(forResource: "source", ofType: "zip")!
        let fileHandle = FileHandle(forReadingAtPath: filePath)
        let data = try #require(try fileHandle?.readToEnd())
        let ZipArchiveReader = try await ZipArchiveReader(ZipMemoryStorage(data))
        let ZipArchiveDirectory = try await ZipArchiveReader.readDirectory()
        print("Loading \(ZipArchiveDirectory[2].filename)")
        let file = try await ZipArchiveReader.readFile(ZipArchiveDirectory[2])
        print(String(decoding: file, as: UTF8.self))
    }

    @Test
    func loadZipDirectory() async throws {
        let filePath = Bundle.module.path(forResource: "source", ofType: "zip")!
        let ZipArchiveReader = try await ZipArchiveReader(ZipFileStorage(filePath))
        let ZipArchiveDirectory = try await ZipArchiveReader.readDirectory()
        #expect(ZipArchiveDirectory.count == 9)
        #expect(ZipArchiveDirectory[0].filename == "Sources/Zip/")
        #expect(ZipArchiveDirectory[8].filename == "Tests/ZipTests/ZipArchiveReaderTests.swift")
    }

    @Test
    func loadZipArchive() async throws {
        let filePath = Bundle.module.path(forResource: "source", ofType: "zip")!
        let ZipArchiveReader = try await ZipArchiveReader(ZipFileStorage(filePath))
        let ZipArchiveDirectory = try await ZipArchiveReader.readDirectory()
        let file = try await ZipArchiveReader.readFile(ZipArchiveDirectory[2])
        print(String(decoding: file, as: UTF8.self))
    }

    @Test
    func loadZip64File() async throws {
        let filePath = Bundle.module.path(forResource: "hello64", ofType: "zip")!
        let ZipArchiveReader = try await ZipArchiveReader(ZipFileStorage(filePath))
        let ZipArchiveDirectory = try await ZipArchiveReader.readDirectory()
        let file = try await ZipArchiveReader.readFile(ZipArchiveDirectory[0])
        #expect(ZipArchiveDirectory[0].filename == "-")
        #expect(String(decoding: file, as: UTF8.self) == "Hello, world!\n")
    }
}
