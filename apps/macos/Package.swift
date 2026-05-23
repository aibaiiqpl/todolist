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
    targets: [
        .executableTarget(
            name: "TodoMenuBarApp"
        )
    ]
)
