import Testing

@testable import ZipArchive

final class EncryptionTests {
    @Test
    func testEncryptDecrypt() {
        var cryptKey = CryptKey(password: "testEncryptDecrypt")
        let bytes = (0..<256).map { _ in UInt8.random(in: 0...255) }
        var encryptedBytes = bytes
        cryptKey.encryptBytes(&encryptedBytes)
        cryptKey = CryptKey(password: "testEncryptDecrypt")
        cryptKey.decryptBytes(&encryptedBytes)

        #expect(bytes == encryptedBytes)
    }
}
