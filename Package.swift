// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "NeTo",
    platforms: [.macOS(.v14)],
    products: [.executable(name: "NeTo", targets: ["NeTo"])],
    targets: [
        .executableTarget(name: "NeTo"),
        .testTarget(name: "NeToTests", dependencies: ["NeTo"])
    ]
)
