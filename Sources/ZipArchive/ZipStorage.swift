/// Protocol for storage
public protocol ZipStorage {
    @discardableResult func seek(_ index: Int) throws(ZipFileStorageError) -> Int
    @discardableResult func seekOffset(_ index: Int) throws(ZipFileStorageError) -> Int
    @discardableResult func seekEnd(_ offset: Int) throws(ZipFileStorageError) -> Int
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

public protocol ZipWriteableStorage: ZipStorage {
    func write<Bytes: Collection>(bytes: Bytes) throws(ZipFileStorageError) -> Int where Bytes.Element == UInt8
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
