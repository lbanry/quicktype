// swift-tools-version: 6.1
import PackageDescription

let package = Package(
    name: "QuickType",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "QuickType", targets: ["QuickType"])
    ],
    targets: [
        .executableTarget(
            name: "QuickType"
        ),
        .testTarget(
            name: "QuickTypeTests",
            dependencies: ["QuickType"]
        )
    ]
)
