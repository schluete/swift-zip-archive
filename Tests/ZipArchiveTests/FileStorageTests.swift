import Foundation
import SystemPackage
import Testing
import ZipArchive

struct ZipMemoryStorageTests {
    let buffer: [UInt8] = [0, 1, 2, 3, 4, 5, 6, 7, 8, 9]

    @Test(arguments: [
        (0, []),
        (3, [0, 1, 2]),
        (8, [0, 1, 2, 3, 4, 5, 6, 7]),
        (10, [0, 1, 2, 3, 4, 5, 6, 7, 8, 9]),
    ])
    func testRead(values: (read: Int, result: [UInt8])) throws {
        let file = ZipMemoryStorage(buffer)
        #expect(try .init(file.read(values.read)) == values.result)
    }

    @Test(arguments: [-1, 11])
    func testReadFails(read: Int) throws {
        let file = ZipMemoryStorage(buffer)
        #expect(throws: ZipFileStorageError.self) { try file.read(read) }
    }

    @Test(arguments: [0, 5, 10])
    func testSeek(offset: Int) throws {
        let file = ZipMemoryStorage(buffer)
        #expect(throws: Never.self) { try file.seek(offset) }
    }

    @Test(arguments: [-1, 11])
    func testSeekFails(offset: Int) throws {
        let file = ZipMemoryStorage(buffer)
        #expect(throws: ZipFileStorageError.self) { try file.seek(offset) }
    }

    @Test(arguments: [
        (0, 5, [0, 1, 2, 3, 4]),
        (3, 8, [3, 4, 5, 6, 7]),
        (4, 7, [4, 5, 6]),
        (8, 10, [8, 9]),
    ])
    func testSeekAndRead(values: (seek: Int, readTo: Int, result: [UInt8])) throws {
        let file = ZipMemoryStorage(buffer)
        try file.seek(values.seek)
        #expect(try .init(file.read(values.readTo - values.seek)) == values.result)
    }

    @Test(arguments: [
        (0, 15),
        (9, 20),
        (10, 1),
    ])
    func testSeekAndReadFail(values: (seek: Int, readTo: Int)) throws {
        let file = ZipMemoryStorage(buffer)
        try file.seek(values.seek)
        #expect(throws: ZipFileStorageError.self) { try file.read(values.readTo) }
    }

    @Test func testWrite() throws {
        let file = ZipMemoryStorage<[UInt8]>()
        try file.seekEnd()
        #expect(file.write(bytes: [1, 2, 3]) == 3)
        try file.seek(0)
        #expect(try file.read(3) == [1, 2, 3])
    }

    @Test func testAppendingWrite() throws {
        let file = ZipMemoryStorage<[UInt8]>([1, 2, 3])
        try file.seekEnd()
        #expect(file.write(bytes: [4, 5, 6]) == 3)
        try file.seek(0)
        #expect(try file.read(6) == [1, 2, 3, 4, 5, 6])
    }

    @Test func testReplacingWrite() throws {
        let file = ZipMemoryStorage<[UInt8]>([1, 2, 3, 4, 5, 6])
        try file.seek(2)
        #expect(file.write(bytes: [7, 8, 9]) == 3)
        try file.seek(0)
        #expect(try file.read(6) == [1, 2, 7, 8, 9, 6])
        try file.seek(5)
        #expect(file.write(bytes: [7, 8, 9]) == 3)
        try file.seek(0)
        #expect(try file.read(8) == [1, 2, 7, 8, 9, 7, 8, 9])
    }
}

final class ZipFileStorageTests {
    let filePath = Bundle.module.path(forResource: "test", ofType: "bin")!
    @Test(arguments: [
        (0, []),
        (3, [0, 1, 2]),
        (8, [0, 1, 2, 3, 4, 5, 6, 7]),
        (10, [0, 1, 2, 3, 4, 5, 6, 7, 8, 9]),
    ])
    func testRead(values: (read: Int, result: [UInt8])) throws {
        let file = try ZipFileStorage(filePath)
        #expect(try .init(file.read(values.read)) == values.result)
    }

    @Test(arguments: [-1, 11])
    func testReadFails(read: Int) throws {
        let file = try ZipFileStorage(filePath)
        #expect(throws: ZipFileStorageError.self) { try file.read(read) }
    }

    @Test(arguments: [0, 5, 10])
    func testSeek(offset: Int) throws {
        let file = try ZipFileStorage(filePath)
        #expect(throws: Never.self) { try file.seek(offset) }
    }

    @Test(arguments: [-1])
    func testSeekFails(offset: Int) throws {
        let file = try ZipFileStorage(filePath)
        #expect(throws: ZipFileStorageError.self) { try file.seek(offset) }
    }

    @Test(arguments: [
        (0, 5, [0, 1, 2, 3, 4]),
        (3, 8, [3, 4, 5, 6, 7]),
        (4, 7, [4, 5, 6]),
        (8, 10, [8, 9]),
    ])
    func testSeekAndRead(values: (seek: Int, readTo: Int, result: [UInt8])) throws {
        let file = try ZipFileStorage(filePath)
        try file.seek(values.seek)
        #expect(try .init(file.read(values.readTo - values.seek)) == values.result)
    }

    @Test(arguments: [
        (0, 15),
        (9, 20),
        (10, 1),
    ])
    func testSeekAndReadFail(values: (seek: Int, readTo: Int)) throws {
        let file = try ZipFileStorage(filePath)
        try file.seek(values.seek)
        #expect(throws: ZipFileStorageError.self) { try file.read(values.readTo) }
    }
    /*
    @Test func testWrite() throws {
        let file = ZipMemoryStorage<[UInt8]>()
        file.seekEnd()
        #expect(file.write(bytes: [1, 2, 3]) == 3)
        try file.seek(0)
        #expect(try file.read(3) == [1, 2, 3])
    }

    @Test func testAppendingWrite() throws {
        let file = ZipMemoryStorage<[UInt8]>([1, 2, 3])
        file.seekEnd()
        #expect(file.write(bytes: [4, 5, 6]) == 3)
        try file.seek(0)
        #expect(try file.read(6) == [1, 2, 3, 4, 5, 6])
    }

    @Test func testReplacingWrite() throws {
        let file = ZipMemoryStorage<[UInt8]>([1, 2, 3, 4, 5, 6])
        try file.seek(2)
        #expect(file.write(bytes: [7, 8, 9]) == 3)
        try file.seek(0)
        #expect(try file.read(6) == [1, 2, 7, 8, 9, 6])
        try file.seek(5)
        #expect(file.write(bytes: [7, 8, 9]) == 3)
        try file.seek(0)
        #expect(try file.read(8) == [1, 2, 7, 8, 9, 7, 8, 9])
    }*/
}
