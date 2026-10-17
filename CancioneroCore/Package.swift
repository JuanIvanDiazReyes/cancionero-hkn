// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "CancioneroCore",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "CancioneroCore", targets: ["CancioneroCore"]),
    ],
    targets: [
        .target(name: "CancioneroCore"),
        .testTarget(name: "CancioneroCoreTests", dependencies: ["CancioneroCore"]),
    ]
)
