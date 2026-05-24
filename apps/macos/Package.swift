// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "TodoMenuBarApp",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "TodoMenuBarApp", targets: ["TodoMenuBarApp"])
    ],
    dependencies: [
        .package(path: "../../shared/swift")
    ],
    targets: [
        .executableTarget(
            name: "TodoMenuBarApp",
            dependencies: [
                .product(name: "TodoShared", package: "swift")
            ]
        )
    ]
)
