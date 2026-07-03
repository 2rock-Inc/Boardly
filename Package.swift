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
    dependencies: [
        // The one allowed third-party dependency — scoped strictly to the
        // real-time sync layer (Sources/BoardlyKit/Realtime).
        .package(url: "https://github.com/socketio/socket.io-client-swift", from: "16.1.0"),
    ],
    targets: [
        .target(
            name: "BoardlyKit",
            dependencies: [
                .product(name: "SocketIO", package: "socket.io-client-swift"),
            ],
            path: "Sources/BoardlyKit"),
        .testTarget(
            name: "BoardlyKitTests",
            dependencies: ["BoardlyKit"],
            path: "Tests/BoardlyKitTests",
            resources: [.copy("Fixtures")]),
    ])
