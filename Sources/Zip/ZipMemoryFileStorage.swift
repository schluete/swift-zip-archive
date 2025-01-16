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
    @discardableResult
    public func seek(_ baseOffset: Int) throws(ZipFileStorageError) -> Int {
        do {
            try self.buffer.seek(baseOffset)
            return self.buffer.position
        } catch {
            throw .init(from: error)
        }
    }

    @inlinable
    @discardableResult
    public func seekOffset(_ offset: Int) throws(ZipFileStorageError) -> Int {
        do {
            try self.buffer.seekOffset(offset)
            return self.buffer.position
        } catch {
            throw .init(from: error)
        }
    }

    @inlinable
    @discardableResult
    public func seekEnd(_ offset: Int = 0) throws(ZipFileStorageError) -> Int {
        do {
            try self.buffer.seekEnd(offset)
            return self.buffer.position
        } catch {
            throw .init(from: error)
        }
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
