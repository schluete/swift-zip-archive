public final class ZipMemoryStorage<Bytes: RangeReplaceableCollection>: ZipReadableStorage, ZipWriteableStorage
where Bytes.Element == UInt8, Bytes.Index == Int {
    @usableFromInline
    var buffer: MemoryBuffer<Bytes>

    @inlinable
    public init() {
        self.buffer = .init()
    }

    @inlinable
    public init(_ buffer: Bytes) {
        self.buffer = .init(buffer)
    }

    @inlinable
    public func read(_ count: Int) throws(ZipFileStorageError) -> Bytes.SubSequence {
        do {
            return try self.buffer.read(count)
        } catch {
            throw .init(from: error)
        }
    }

    @inlinable
    public func write<WriteBytes: Collection>(bytes: WriteBytes) -> Int where WriteBytes.Element == UInt8 {
        self.buffer.write(bytes: bytes)
    }

    @inlinable
    public func seek(_ baseOffset: Int) throws(ZipFileStorageError) {
        do {
            return try self.buffer.seek(baseOffset)
        } catch {
            throw .init(from: error)
        }
    }

    @inlinable
    public func seekOffset(_ offset: Int) throws(ZipFileStorageError) {
        do {
            return try self.buffer.seekOffset(offset)
        } catch {
            throw .init(from: error)
        }
    }

    @inlinable
    public func seekEnd() {
        self.buffer.seekEnd()
    }

    @inlinable
    public var length: Int { self.buffer.length }
}

extension ZipFileStorageError {
    @usableFromInline
    init(from memoryBufferError: MemoryBufferError) {
        switch memoryBufferError {
        case MemoryBufferError.readingPastEndOfBuffer:
            self = .readingPastEndOfFile
        case MemoryBufferError.offsetOutOfRange:
            self = .fileOffsetOutOfRange
        }
    }
}
