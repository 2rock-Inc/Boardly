// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "BoardlyKit",
    platforms: [
        .iOS(.v17),
        .macOS(.v14),
    ],
    products: [
        .library(name: "BoardlyKit", targets: ["BoardlyKit"]),
    ],
    targets: [
        .target(
            name: "BoardlyKit",
            dependencies: [],
            path: "Sources/BoardlyKit"
        ),
        .testTarget(
            name: "BoardlyKitTests",
            dependencies: ["BoardlyKit"],
            path: "Tests/BoardlyKitTests",
            resources: [.copy("Fixtures")]
        ),
    ]
)
