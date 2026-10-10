// swift-tools-version: 6.0
import PackageDescription
let package = Package(
    name: "Caffeine",
    platforms: [.macOS(.v13)],
    products: [
        .executable(name: "Caffeine", targets: ["Caffeine"])
    ],
    targets: [
        .target(name: "CaffeineCore", path: "Caffeine/Core"),
        .executableTarget(name: "Caffeine", dependencies: ["CaffeineCore"], path: "Caffeine/Sources"),
        .testTarget(name: "CaffeineCoreTests", dependencies: ["CaffeineCore"], path: "Caffeine/Tests")
    ]
)
