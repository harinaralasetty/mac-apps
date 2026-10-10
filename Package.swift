// swift-tools-version: 6.0
import PackageDescription
let package = Package(
    name: "CaffeinateUI",
    platforms: [.macOS(.v13)],
    products: [
        .executable(name: "CaffeinateUI", targets: ["CaffeinateUI"])
    ],
    targets: [
        .target(name: "CaffeinateUICore", path: "CaffeinateUI/Core"),
        .executableTarget(name: "CaffeinateUI", dependencies: ["CaffeinateUICore"], path: "CaffeinateUI/Sources"),
        .testTarget(name: "CaffeinateUICoreTests", dependencies: ["CaffeinateUICore"], path: "CaffeinateUI/Tests")
    ]
)
