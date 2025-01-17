# ZipArchive

Zip archive reader written in Swift

## Usage

To parse a zip archive stored on disk 
```swift
let fileStorage = try ZipFileStorage(filename)
let zipArchiveReader = try await ZipArchiveReader(fileStorage)
let zipDirectory = try await ZipArchiveReader.readDirectory()
let zipFileRecord = zipDirectory.first { $0.filename == "test.txt"}
let file = ZipArchiveReader.readFile(zipFileRecord)
```

If your zip archive is stored in memory you can setup the `ZipArchiveReader` to read from memory.

```swift
let memoryStorage = try ZipMemoryStorage(zipBuffer)
let zipArchiveReader = try ZipArchiveReader(memoryStorage)
```

## Status

ZipArchive currently supports
- Deflate decompression
- Zip64
- CRC32 checks


