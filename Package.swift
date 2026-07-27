// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "TorrServerManager",
    platforms: [
        .macOS(.v12)
    ],
    products: [
        .executable(
            name: "TorrServerManager",
            targets: ["TorrServerManager"]
        )
    ],
    targets: [
        .executableTarget(
            name: "TorrServerManager",
            path: "Sources"
        )
    ]
)
