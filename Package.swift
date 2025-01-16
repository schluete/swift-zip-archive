// swift-tools-version: 6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "swift-zip",
    platforms: [.macOS(.v12), .iOS(.v15), .tvOS(.v15)],
    products: [
        .library(name: "Zip", targets: ["Zip"])
    ],
    targets: [
        .target(
            name: "CZipZlib",
            linkerSettings: [
                .linkedLibrary("z")
            ]
        ),
        .target(name: "Zip", dependencies: ["CZipZlib"]),
        .testTarget(
            name: "ZipTests",
            dependencies: ["Zip"],
            resources: [.process("resources")]
        ),
    ]
)
