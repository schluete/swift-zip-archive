import Foundation
import Testing

@testable import Zip

struct ZipFileReaderTests {
    @Test
    func loadZipDirectoryFromMemory() async throws {
        let filePath = Bundle.module.path(forResource: "source", ofType: "zip")!
        let fileHandle = FileHandle(forReadingAtPath: filePath)
        let data = try #require(try fileHandle?.readToEnd())
        let zipFileReader = try await ZipFileReader(ZipMemoryStorage(data))
        let zipFileDirectory = try await zipFileReader.readDirectory()
        #expect(zipFileDirectory.count == 9)
        #expect(zipFileDirectory[0].filename == "Sources/Zip/")
        #expect(zipFileDirectory[8].filename == "Tests/ZipTests/ZipFileReaderTests.swift")
    }

    @Test
    func loadZipFileFromMemory() async throws {
        let filePath = Bundle.module.path(forResource: "source", ofType: "zip")!
        let fileHandle = FileHandle(forReadingAtPath: filePath)
        let data = try #require(try fileHandle?.readToEnd())
        let zipFileReader = try await ZipFileReader(ZipMemoryStorage(data))
        let zipFileDirectory = try await zipFileReader.readDirectory()
        print("Loading \(zipFileDirectory[2].filename)")
        let file = try await zipFileReader.readFile(zipFileDirectory[2])
        print(String(decoding: file, as: UTF8.self))
    }

    @Test
    func loadZipDirectory() async throws {
        let filePath = Bundle.module.path(forResource: "source", ofType: "zip")!
        let fileStorage = try ZipFileStorage(filePath)
        let zipFileReader = try await ZipFileReader(fileStorage)
        let zipFileDirectory = try await zipFileReader.readDirectory()
        #expect(zipFileDirectory.count == 9)
        #expect(zipFileDirectory[0].filename == "Sources/Zip/")
        #expect(zipFileDirectory[8].filename == "Tests/ZipTests/ZipFileReaderTests.swift")
    }

    @Test
    func loadZipFile() async throws {
        let filePath = Bundle.module.path(forResource: "source", ofType: "zip")!
        let fileStorage = try ZipFileStorage(filePath)
        let zipFileReader = try await ZipFileReader(fileStorage)
        let zipFileDirectory = try await zipFileReader.readDirectory()
        let file = try await zipFileReader.readFile(zipFileDirectory[2])
        print(String(decoding: file, as: UTF8.self))
    }
}
