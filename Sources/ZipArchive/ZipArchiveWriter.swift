public final class ZipArchiveWriter<Storage: ZipWriteableStorage> {
    enum Edit {
        case addFile(fileHeader: Zip.FileHeader, bytes: [UInt8])
        case addCompressedFile(fileHeader: Zip.FileHeader, bytes: [UInt8])
    }

    var reader: ZipArchiveReader<Storage>

    init(_ file: Storage) throws {
        self.reader = try .init(file)
    }

    func write() throws {
        try self.reader.file.seek(reader.endOfCentralDirectory.offsetOfCentralDirectory)
    }
}
