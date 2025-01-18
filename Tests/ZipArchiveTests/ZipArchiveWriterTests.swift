import Testing

@testable import ZipArchive

struct ZipArchiveWriterTests {
    @Test
    func testCreateEmptyZipArchive() throws {
        let zipFileWrite = ZipArchiveWriter()
        let buffer = try zipFileWrite.writeToBuffer()
        #expect(buffer == [UInt8]([80, 75, 5, 6, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0])[...])
    }

    @Test
    func testAddingFileToEmptyZipArchive() throws {
        let zipFileWrite = ZipArchiveWriter()
        try zipFileWrite.addFile(filename: "Hello.txt", contents: .init("Hello, world!".utf8))
        let buffer = try zipFileWrite.writeToBuffer()
        let zipArchiveReader = try ZipArchiveReader(bytes: buffer)
        let directory = try zipArchiveReader.readDirectory()
        #expect(directory.count == 1)
        #expect(directory.first?.filename == "Hello.txt")
        let fileHeader = try #require(directory.first)
        let fileContents = try zipArchiveReader.readFile(fileHeader)
        #expect(fileContents == .init("Hello, world!".utf8))
    }

    @Test
    func testAddingFileToNonEmptyZipArchive() throws {
        // write original zip archive
        let buffer = try {
            let zipFileWrite = ZipArchiveWriter()
            try zipFileWrite.addFile(filename: "Hello.txt", contents: .init("Hello, world!".utf8))
            return try zipFileWrite.writeToBuffer()
        }()
        let zipFileWriter = try ZipArchiveWriter(bytes: [UInt8](buffer))
        try zipFileWriter.addFile(filename: "Goodbye.txt", contents: .init("Goodbye, world!".utf8))
        let buffer2 = try zipFileWriter.writeToBuffer()

        let zipArchiveReader = try ZipArchiveReader(bytes: buffer2)
        let directory = try zipArchiveReader.readDirectory()
        #expect(directory.count == 2)
        #expect(directory.first?.filename == "Hello.txt")
        let fileHeader = try #require(directory.first)
        let fileContents = try zipArchiveReader.readFile(fileHeader)
        #expect(fileContents == .init("Hello, world!".utf8))
        #expect(directory.last?.filename == "Goodbye.txt")
        let fileHeader2 = try #require(directory.last)
        let fileContents2 = try zipArchiveReader.readFile(fileHeader2)
        #expect(fileContents2 == .init("Goodbye, world!".utf8))
    }
}
