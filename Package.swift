// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Punt",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(
            name: "Punt",
            path: "Sources/Punt"
        )
    ]
)
