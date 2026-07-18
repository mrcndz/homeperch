// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "HomePerch",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "HomePerch",
            path: "Sources/HomePerch"
        )
    ]
)
