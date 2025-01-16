public protocol ZipFileStorage {
    func seek(_ index: Int) async throws(ZipFileStorageError)
    func seekOffset(_ index: Int) async throws(ZipFileStorageError)
    func seekEnd() async throws(ZipFileStorageError)
    var length: Int { get async }
}

public protocol ZipReadableFileStorage: ZipFileStorage {
    associatedtype Buffer: RangeReplaceableCollection where Buffer.Element == UInt8, Buffer.Index == Int
    func read(_ count: Int) async throws(ZipFileStorageError) -> Buffer
}

extension ZipReadableFileStorage {
    @inlinable
    public func readInteger<T: FixedWidthInteger>(
        as: T.Type = T.self
    ) async throws(ZipFileStorageError) -> T {
        let buffer = try await read(MemoryLayout<T>.size)
        var value: T = 0
        withUnsafeMutableBytes(of: &value) { valuePtr in
            valuePtr.copyBytes(from: buffer)
        }
        return value
    }

    @inlinable
    public func readString(length: Int) async throws(ZipFileStorageError) -> String {
        let buffer = try await read(length)
        return String(decoding: buffer, as: UTF8.self)
    }

    @inlinable
    public func readBytes(length: Int) async throws(ZipFileStorageError) -> [UInt8] {
        let buffer = try await read(length)
        return .init(buffer)
    }

    @inlinable
    public func readIntegers<each T: FixedWidthInteger>(_ type: repeat (each T).Type) async throws(ZipFileStorageError) -> (repeat each T) {
        func memorySize<Value>(_ value: Value.Type) -> Int {
            MemoryLayout<Value>.size
        }
        var count = 0
        for t in repeat each type {
            count += memorySize(t)
        }
        let bytes = try await read(count)
        var buffer = MemoryBuffer(bytes)
        do {
            return try buffer.readIntegers(repeat (each type))
        } catch {
            throw .init(from: error)
        }
    }
}

public protocol ZipWriteableFileStorage: ZipFileStorage {
    func write<Bytes: Collection>(bytes: Bytes) async throws(ZipFileStorageError) -> Int where Bytes.Element == UInt8
}

public struct ZipFileStorageError: Error {
    internal enum Value {
        case fileOffsetOutOfRange
        case readPastEndOfFile
    }
    internal let value: Value

    public static var fileOffsetOutOfRange: Self { .init(value: .fileOffsetOutOfRange) }
    public static var readingPastEndOfFile: Self { .init(value: .readPastEndOfFile) }
}
