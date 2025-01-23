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
    static func remove(_ filePath: FilePath) {
        _ = filePath.withPlatformString { filename in
            system_remove(filename)
        }
    }
}

func system_remove(
    _ path: UnsafePointer<CInterop.PlatformChar>
) -> CInt {
    remove(path)
}
