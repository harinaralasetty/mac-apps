// swift-tools-version: 6.0
import PackageDescription
let package = Package(
    name: "MacApps",
    platforms: [.macOS(.v13)],
    products: [
        .executable(name: "MicMute", targets: ["MicMute"]),
        .executable(name: "Caffeine", targets: ["Caffeine"])
    ],
    targets: [
        .executableTarget(name: "MicMute", path: "MicMute/Sources"),
        .target(name: "CaffeineCore", path: "Caffeine/Core"),
        .executableTarget(name: "Caffeine", dependencies: ["CaffeineCore"], path: "Caffeine/Sources"),
        .testTarget(name: "CaffeineCoreTests", dependencies: ["CaffeineCore"], path: "Caffeine/Tests")
    ]
)
