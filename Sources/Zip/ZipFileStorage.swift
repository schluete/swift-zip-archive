import SystemPackage

public class ZipFileStorage: ZipReadableStorage {
    let fileDescriptor: FileDescriptor
    public let length: Int

    public init(_ filename: String) throws {
        self.fileDescriptor = try FileDescriptor.open(
            .init(filename),
            .readOnly
        )
        self.length = try numericCast(self.fileDescriptor.seek(offset: 0, from: .end))
        try self.fileDescriptor.seek(offset: 0, from: .start)
        print("Opening \(filename), size: \(self.length)")
    }

    deinit {
        try? fileDescriptor.close()
    }

    public func read(_ count: Int) throws(ZipFileStorageError) -> [UInt8] {
        guard count >= 0 else { throw .fileOffsetOutOfRange }
        guard count > 0 else { return [] }
        let buffer: [UInt8]
        do {
            buffer = try .init(unsafeUninitializedCapacity: count) { buffer, readCount in
                readCount = try self.fileDescriptor.read(into: .init(buffer))
            }
        } catch {
            throw .internalError
        }
        guard buffer.count == count else { throw ZipFileStorageError.readingPastEndOfFile }
        return buffer
    }

    public func seek(_ index: Int) throws(ZipFileStorageError) {
        guard index <= length else { throw .fileOffsetOutOfRange }
        do {
            try self.fileDescriptor.seek(offset: numericCast(index), from: .start)
        } catch let error as Errno where error == .invalidArgument {
            throw .fileOffsetOutOfRange
        } catch {
            throw .internalError
        }
    }

    public func seekOffset(_ index: Int) throws(ZipFileStorageError) {
        do {
            try self.fileDescriptor.seek(offset: numericCast(index), from: .current)
        } catch let error as Errno where error == .invalidArgument {
            throw .fileOffsetOutOfRange
        } catch {
            throw .internalError
        }
    }

    public func seekEnd() throws(ZipFileStorageError) {
        do {
            try self.fileDescriptor.seek(offset: 0, from: .end)
        } catch {
            throw .internalError
        }
    }
}
