import SystemPackage

public class ZipFileStorage: ZipReadableStorage {
    @usableFromInline
    let fileDescriptor: FileDescriptor

    @inlinable
    public init(_ filename: String) throws {
        self.fileDescriptor = try FileDescriptor.open(
            .init(filename),
            .readOnly
        )
    }

    deinit {
        try? fileDescriptor.close()
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
