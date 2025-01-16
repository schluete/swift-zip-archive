import CZipZlib

protocol ZipCompressor {
    func inflate(from: [UInt8], uncompressedSize: Int) throws -> [UInt8]
}

typealias ZipCompressionMethodsMap = [Zip.FileCompressionMethod: any ZipCompressor]

struct DoNothingCompressor: ZipCompressor {
    func inflate(from: [UInt8], uncompressedSize: Int) throws -> [UInt8] {
        from
    }
}

class ZlibDeflateCompressor: ZipCompressor {
    let windowBits: Int32

    init(windowBits: Int32) {
        self.windowBits = windowBits
    }

    func inflate(from: [UInt8], uncompressedSize: Int) throws -> [UInt8] {
        var stream = z_stream()
        stream.zalloc = nil
        stream.zfree = nil
        stream.opaque = nil
        let rt = CZipZlib_inflateInit2(&stream, -windowBits)
        guard rt == Z_OK else { throw ZipArchiveReaderError.compressionError }

        var from = from
        return try .init(unsafeUninitializedCapacity: uncompressedSize) { toBuffer, count in
            try from.withUnsafeMutableBytes { fromBuffer in
                stream.avail_in = UInt32(fromBuffer.count)
                stream.next_in = CZipZlib_voidPtr_to_BytefPtr(fromBuffer.baseAddress!)
                stream.avail_out = UInt32(toBuffer.count)
                stream.next_out = CZipZlib_voidPtr_to_BytefPtr(toBuffer.baseAddress!)

                let rt = CZipZlib.inflate(&stream, Z_FINISH)
                switch rt {
                case Z_OK:
                    break
                case Z_BUF_ERROR:
                    throw ZipArchiveReaderError.compressionError
                case Z_DATA_ERROR:
                    throw ZipArchiveReaderError.compressionError
                case Z_MEM_ERROR:
                    throw ZipArchiveReaderError.compressionError
                case Z_STREAM_END:
                    break
                default:
                    throw ZipArchiveReaderError.compressionError
                }
            }
            count = uncompressedSize
        }
    }
}
