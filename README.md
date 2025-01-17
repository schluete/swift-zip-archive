# ZipArchive

Zip archive reader written in Swift

## Usage

To parse a zip archive stored on disk 
```swift
let zipArchiveReader = try await ZipArchiveReader.withFile(filename) { reader in
    let zipDirectory = try await reader.readDirectory()
    let zipFileRecord = zipDirectory.first { $0.filename == "test.txt"}
    let file = reader.readFile(zipFileRecord)
}
```

If your zip archive is stored in memory you can setup the `ZipArchiveReader` to read from memory.

```swift
let reader = try ZipArchiveReader(zipBuffer)
let zipDirectory = try await reader.readDirectory()
let zipFileRecord = zipDirectory.first { $0.filename == "test.txt"}
let file = reader.readFile(zipFileRecord)
```

## Status

ZipArchive currently supports
- Deflate decompression
- Zip64
- CRC32 checks
 

