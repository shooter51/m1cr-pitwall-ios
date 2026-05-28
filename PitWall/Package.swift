// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "PitWall",
    platforms: [
        .iOS(.v17),
        .macOS(.v14),
    ],
    products: [
        .library(name: "PitWall", targets: ["PitWall"]),
    ],
    targets: [
        .target(
            name: "PitWall",
            path: "Sources/PitWall",
            swiftSettings: [
                .enableUpcomingFeature("StrictConcurrency"),
            ]
        ),
        .testTarget(
            name: "PitWallTests",
            dependencies: ["PitWall"],
            path: "Sources/PitWallTests",
            resources: [
                .copy("Fixtures"),
            ]
        ),
    ]
)
