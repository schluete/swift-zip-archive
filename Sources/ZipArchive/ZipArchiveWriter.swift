public final class ZipArchiveWriter<Storage: ZipWriteableStorage> {
    enum Edit {
        case addFile(fileHeader: Zip.FileHeader, bytes: [UInt8])
        case addCompressedFile(fileHeader: Zip.FileHeader, bytes: [UInt8])
    }

    var reader: ZipArchiveReader<Storage>
    var file: Storage { reader.file }

    init(_ file: Storage) throws {
        self.reader = try .init(file)
    }

    func write() throws {
        try self.reader.file.truncate(reader.endOfCentralDirectory.offsetOfCentralDirectory)
    }

    func writeFileHeader(_ fileHeader: Zip.FileHeader32) throws {

    }

    func writeLocalFileHeader(_ fileHeader: Zip.LocalFileHeader32) throws {

    }

    func writeZip64EndOfCentralDirectory(_ zip64EndOfCentralDirectory: Zip.Zip64EndOfCentralDirectory) throws {
        try self.file.writeIntegers(
            Zip.zip64EndOfCentralDirectorySignature,
            UInt16(0), // version make by
            UInt16(0), // version needed
            zip64EndOfCentralDirectory.diskNumber,
            zip64EndOfCentralDirectory.diskNumberCentralDirectoryStarts,
            zip64EndOfCentralDirectory.diskEntries,
            zip64EndOfCentralDirectory.totalEntries, 
            zip64EndOfCentralDirectory.centralDirectorySize,
            zip64EndOfCentralDirectory.offsetOfCentralDirectory
        )
    }

    func writeZip64EndOfCentralLocator(_ zip64EndOfCentralLocator: Zip.Zip64EndOfCentralLocator) throws {
        try self.file.writeIntegers(
            Zip.zip64EndOfCentralLocatorSignature,
            zip64EndOfCentralLocator.diskNumberCentralDirectoryStarts,
            zip64EndOfCentralLocator.relativeOffsetEndOfCentralDirectory,
            zip64EndOfCentralLocator.totalNumberOfDisks
        )
    }

    func writeEndOfCentralDirectory(_ endOfCentralDirectory: Zip.EndOfCentralDirectory32) throws {
        try self.file.writeIntegers(
            Zip.endOfCentralDirectorySignature,
            endOfCentralDirectory.diskNumber,
            endOfCentralDirectory.diskNumberCentralDirectoryStarts,
            endOfCentralDirectory.diskEntries,
            endOfCentralDirectory.totalEntries,
            endOfCentralDirectory.centralDirectorySize,
            endOfCentralDirectory.offsetOfCentralDirectory,
            endOfCentralDirectory.comment.utf8.count
        )
        try self.file.writeString(endOfCentralDirectory.comment)
    }
}
