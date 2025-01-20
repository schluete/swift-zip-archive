/// Protocol for storage
public protocol ZipStorage {
    @discardableResult func seek(_ index: Int64) throws(ZipFileStorageError) -> Int64
    @discardableResult func seekOffset(_ index: Int64) throws(ZipFileStorageError) -> Int64
    @discardableResult func seekEnd(_ offset: Int64) throws(ZipFileStorageError) -> Int64
}

public protocol ZipReadableStorage: ZipStorage {
    associatedtype Buffer: RangeReplaceableCollection where Buffer.Element == UInt8, Buffer.Index == Int
    func read(_ count: Int) throws(ZipFileStorageError) -> Buffer
}

extension ZipReadableStorage {
    @inlinable
    public func readInteger<T: FixedWidthInteger>(
        as: T.Type = T.self
    ) throws(ZipFileStorageError) -> T {
        let buffer = try read(MemoryLayout<T>.size)
        var value: T = 0
        withUnsafeMutableBytes(of: &value) { valuePtr in
            valuePtr.copyBytes(from: buffer)
        }
        return value
    }

    @inlinable
    public func readString(length: Int) throws(ZipFileStorageError) -> String {
        let buffer = try read(length)
        return String(decoding: buffer, as: UTF8.self)
    }

    @inlinable
    public func readBytes(length: Int) throws(ZipFileStorageError) -> [UInt8] {
        let buffer = try read(length)
        return .init(buffer)
    }

    @inlinable
    public func readIntegers<each T: FixedWidthInteger>(_ type: repeat (each T).Type) throws(ZipFileStorageError) -> (repeat each T) {
        func memorySize<Value>(_ value: Value.Type) -> Int {
            MemoryLayout<Value>.size
        }
        var size = 0
        for t in repeat each type {
            size += memorySize(t)
        }
        let bytes = try read(size)
        var buffer = MemoryBuffer(bytes)
        do {
            return try buffer.readIntegers(repeat (each type))
        } catch {
            throw .init(from: error)
        }
    }
}

extension ZipReadableStorage {
    func copy(length: Int64, to storage: some ZipWriteableStorage) throws {
        var amountToCopy = length
        // TODO: Optimise this
        while amountToCopy > 0 {
            let chunkSize: Int = min(numericCast(amountToCopy), 65536)
            amountToCopy -= numericCast(chunkSize)
            let bytes = try self.read(chunkSize)
            try storage.write(bytes: bytes)
        }
    }
}

public protocol ZipWriteableStorage: ZipReadableStorage {
    func write<Bytes: Collection>(bytes: Bytes) throws(ZipFileStorageError) where Bytes.Element == UInt8
    func truncate(_ size: Int64) throws
}

extension ZipWriteableStorage {
    @inlinable
    public func writeString(_ string: String) throws(ZipFileStorageError) {
        try self.write(bytes: string.utf8)
    }

    @inlinable
    public func writeInteger<T: FixedWidthInteger>(
        _ value: T
    ) throws(ZipFileStorageError) {
        do {
            try withUnsafeBytes(of: value) { valuePtr in
                try write(bytes: valuePtr)
            }
        } catch let error as ZipFileStorageError {
            throw error
        } catch {
            throw .internalError
        }
    }

    @inlinable
    public func writeIntegers<each T: FixedWidthInteger>(_ value: repeat each T) throws(ZipFileStorageError) {
        try (repeat self.writeInteger(each value))
    }
}

public struct ZipFileStorageError: Error {
    internal enum Value {
        case fileOffsetOutOfRange
        case readPastEndOfFile
        case fileClosed
        case fileDoesNotExist
        case internalError
    }
    internal let value: Value

    public static var fileOffsetOutOfRange: Self { .init(value: .fileOffsetOutOfRange) }
    public static var readingPastEndOfFile: Self { .init(value: .readPastEndOfFile) }
    public static var fileClosed: Self { .init(value: .fileClosed) }
    public static var fileDoesNotExist: Self { .init(value: .fileDoesNotExist) }
    public static var internalError: Self { .init(value: .internalError) }
}
