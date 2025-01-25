# ZipArchive

Zip archive reader and writer written in Swift

## Usage

### Reading

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

### Writing

To write to a file on disk you can either append to an existing zip file.

```swift
try ZipArchiveWriter.withFile(filename) { writer in
    try writer.addFile(filename: "Hello.txt", contents: .init("Hello, world!".utf8))
}
```

Or you can create a new zip file by adding the `.create` option.

```swift
try ZipArchiveWriter.withFile(filename, options: .create) { writer in
    try writer.addFile(filename: "Hello.txt", contents: .init("Hello, world!".utf8))
}
```

There are equivalent operations for writing to a memory buffer as well

```swift
let writer = ZipArchiveWriter()
try writer.addFile(filename: "Hello.txt", contents: .init("Hello, world!".utf8))
let buffer = try writer.finalizeBuffer()
```

And to append to a zip file in memory 

```swift
let writer = ZipArchiveWriter(bytes: zipBuffer)
try writer.addFile(filename: "Hello.txt", contents: .init("Hello, world!".utf8))
let buffer = try writer.finalizeBuffer()
```

## Status

ZipArchive currently supports
- Deflate decompression
- Zip64
- CRC32 checks
- Traditional PKWARE Decryption/Encryption
 

