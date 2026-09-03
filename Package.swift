// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "TabFinder",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "TabFinder", targets: ["TabFinder"]),
    ],
    targets: [
        .executableTarget(name: "TabFinder"),
        .testTarget(name: "TabFinderTests", dependencies: ["TabFinder"]),
    ]
)
