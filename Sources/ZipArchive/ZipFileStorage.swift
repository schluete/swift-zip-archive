import SystemPackage

public struct ZipFileStorage: ZipReadableStorage {
    @usableFromInline
    let fileDescriptor: FileDescriptor

    @inlinable
    init(_ fileDescriptor: FileDescriptor) throws {
        self.fileDescriptor = fileDescriptor
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
    public func seek(_ index: Int) throws(ZipFileStorageError) -> Int {
        do {
            let offset = try self.fileDescriptor.seek(offset: numericCast(index), from: .start)
            return numericCast(offset)
        } catch let error as Errno where error == .invalidArgument {
            throw .fileOffsetOutOfRange
        } catch {
            throw .internalError
        }
    }

    @inlinable
    @discardableResult
    public func seekOffset(_ index: Int) throws(ZipFileStorageError) -> Int {
        do {
            let offset = try self.fileDescriptor.seek(offset: numericCast(index), from: .current)
            return numericCast(offset)
        } catch let error as Errno where error == .invalidArgument {
            throw .fileOffsetOutOfRange
        } catch {
            throw .internalError
        }
    }

    @inlinable
    @discardableResult
    public func seekEnd(_ offset: Int = 0) throws(ZipFileStorageError) -> Int {
        do {
            let offset = try self.fileDescriptor.seek(offset: numericCast(offset), from: .end)
            return numericCast(offset)
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
        let value: Value
        do {
            let zipArchiveReader = try ZipArchiveReader(ZipFileStorage(fileDescriptor))
            value = try process(zipArchiveReader)
        } catch {
            try? fileDescriptor.close()
            throw error
        }
        try fileDescriptor.close()
        return value
    }

}
