import Testing

@testable import ZipArchive

struct ZipArchiveWriterTests {
    @Test
    func testCreateEmptyZipArchive() throws {
        let zipFileWrite = ZipArchiveWriter()
        #expect(try zipFileWrite.writeToBuffer() == [UInt8]([80, 75, 5, 6, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0])[...])
    }

    @Test
    func testAddingFileToEmptyZipArchive() throws {
        let zipFileWrite = ZipArchiveWriter()
        try zipFileWrite.addFile(filename: "Hello.txt", contents: .init("Hello, world!".utf8))
        _ = try zipFileWrite.writeToBuffer()
        //#expect(zipFileWrite.buffer() == [UInt8]([80, 75, 5, 6, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0])[...])
    }
}
