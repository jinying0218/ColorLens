// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "ColorLens",
    platforms: [.macOS(.v13)],
    products: [.executable(name: "ColorLens", targets: ["ColorLens"])],
    targets: [
        .target(name: "ColorCore"),
        .executableTarget(name: "ColorLens", dependencies: ["ColorCore"]),
        .testTarget(name: "ColorCoreTests", dependencies: ["ColorCore"]),
        .testTarget(name: "ColorLensTests", dependencies: ["ColorLens", "ColorCore"])
    ]
)
