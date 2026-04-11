// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "SentinelSDK",
    platforms: [
        .iOS(.v16),
        .macOS(.v13),
        .tvOS(.v16),
        .watchOS(.v9),
    ],
    products: [
        .library(name: "SentinelCore", targets: ["SentinelCore"]),
        .library(name: "AppAnalytics", targets: ["AppAnalytics"]),
        .library(name: "SentinelHTTPTransport", targets: ["SentinelHTTPTransport"]),
    ],
    targets: [
        .target(name: "SentinelCore"),
        .target(name: "AppAnalytics", dependencies: ["SentinelCore"]),
        .target(name: "SentinelHTTPTransport", dependencies: ["SentinelCore", "AppAnalytics"]),
        .testTarget(name: "SentinelCoreTests", dependencies: ["SentinelCore"]),
        .testTarget(name: "AppAnalyticsTests", dependencies: ["AppAnalytics"]),
        .testTarget(name: "SentinelHTTPTransportTests", dependencies: ["SentinelHTTPTransport"]),
    ]
)
