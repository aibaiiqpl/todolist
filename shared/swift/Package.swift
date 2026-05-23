// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "TodoShared",
    platforms: [
        .iOS(.v16),
        .macOS(.v13)
    ],
    products: [
        .library(
            name: "TodoShared",
            targets: ["TodoShared"]
        )
    ],
    targets: [
        .target(name: "TodoShared"),
        .testTarget(
            name: "TodoSharedTests",
            dependencies: ["TodoShared"]
        )
    ]
)
