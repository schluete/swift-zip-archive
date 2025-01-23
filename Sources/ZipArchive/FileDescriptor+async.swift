import SystemPackage

#if canImport(Darwin)
import Darwin
#elseif canImport(Glibc)
import Glibc
#elseif canImport(Musl)
import Musl
#elseif canImport(WASILibc)
import WASILibc
#elseif os(Windows)
import ucrt
#elseif canImport(Android)
import Android
#else
#error("Unsupported Platform")
#endif

extension FileDescriptor {
    func closeAfter<R: Sendable>(
        isolation: isolated (any Actor)? = #isolation,
        body: () async throws -> R
    ) async throws -> R {
        // No underscore helper, since the closure's throw isn't necessarily typed.
        let result: R
        do {
            result = try await body()
        } catch {
            _ = try? self.close()  // Squash close error and throw closure's
            throw error
        }
        try self.close()
        return result
    }
}
