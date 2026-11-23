// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "AutoHideCore",
    platforms: [.macOS(.v14)],
    products: [.library(name: "AutoHideCore", targets: ["AutoHideCore"])],
    targets: [
        .target(name: "AutoHideCore", path: "Sources/Core"),
        .testTarget(name: "AutoHideCoreTests", dependencies: ["AutoHideCore"])
    ]
)
