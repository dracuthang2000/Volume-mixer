// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "VolumeMixer",
    platforms: [.macOS("14.2")],
    targets: [
        .executableTarget(
            name: "VolumeMixer",
            path: "Sources/VolumeMixer",
            swiftSettings: [.swiftLanguageMode(.v5)]
        )
    ]
)
