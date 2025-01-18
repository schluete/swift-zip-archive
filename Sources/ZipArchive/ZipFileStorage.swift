import SystemPackage

public struct ZipFileStorage: ZipReadableStorage {
    @usableFromInline
    let fileDescriptor: FileDescriptor
    @usableFromInline
    let length: Int64

    @inlinable
    init(_ fileDescriptor: FileDescriptor) throws {
        self.fileDescriptor = fileDescriptor
        self.length = try fileDescriptor.seek(offset: 0, from: .end)
        _ = try fileDescriptor.seek(offset: 0, from: .start)
    }

    @inlinable
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

    @inlinable
    @discardableResult
    public func seek(_ index: Int64) throws(ZipFileStorageError) -> Int64 {
        do {
            let offset = try self.fileDescriptor.seek(offset: index, from: .start)
            return offset
        } catch let error as Errno where error == .invalidArgument {
            throw .fileOffsetOutOfRange
        } catch {
            throw .internalError
        }
    }

    @inlinable
    @discardableResult
    public func seekOffset(_ index: Int64) throws(ZipFileStorageError) -> Int64 {
        do {
            let offset = try self.fileDescriptor.seek(offset: index, from: .current)
            return offset
        } catch let error as Errno where error == .invalidArgument {
            throw .fileOffsetOutOfRange
        } catch {
            throw .internalError
        }
    }

    @inlinable
    @discardableResult
    public func seekEnd(_ offset: Int64 = 0) throws(ZipFileStorageError) -> Int64 {
        do {
            let offset = try self.fileDescriptor.seek(offset: offset, from: .end)
            return offset
        } catch {
            throw .internalError
        }
    }
}

extension ZipArchiveReader where Storage == ZipFileStorage {
    public static func withFile<Value>(_ filename: String, process: (ZipArchiveReader) throws -> Value) throws -> Value {
        let fileDescriptor = try FileDescriptor.open(
            .init(filename),
            .readOnly
        )
        return try fileDescriptor.closeAfter {
            let zipArchiveReader = try ZipArchiveReader(ZipFileStorage(fileDescriptor))
            return try process(zipArchiveReader)
        }
    }

}
