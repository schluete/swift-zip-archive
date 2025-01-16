import Foundation
import Testing

@testable import Zip

struct ZipFileReaderTests {
    @Test
    func loadZip() async throws {
        let filePath = Bundle.module.path(forResource: "source", ofType: "zip")!
        let fileHandle = FileHandle(forReadingAtPath: filePath)
        let data = try #require(try fileHandle?.readToEnd())
        let zipFileReader = try await ZipFileReader(ZipFileMemoryStorage(data))
        #expect(zipFileReader.directory.count == 9)
        #expect(zipFileReader.directory[0].filename == "Sources/Zip/")
        #expect(zipFileReader.directory[8].filename == "Tests/ZipTests/ZipFileReaderTests.swift")
        print(zipFileReader.directory.map { $0.filename })
    }
}
