// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "SmokeClient",
    platforms: [
        .iOS(.v16),
        .macOS(.v13),
        .tvOS(.v16),
        .watchOS(.v9),
    ],
    dependencies: [
        .package(path: "../.."),
    ],
    targets: [
        .executableTarget(
            name: "SmokeClient",
            dependencies: [
                .product(name: "SentinelCore", package: "sentinel-sdk"),
                .product(name: "AppAnalytics", package: "sentinel-sdk"),
                .product(name: "SentinelHTTPTransport", package: "sentinel-sdk"),
            ]
        ),
    ]
)
