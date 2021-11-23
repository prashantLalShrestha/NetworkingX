// swift-tools-version:5.2
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "NetworkingX",
    platforms: [.iOS(.v11), .macOS(.v10_13), .tvOS(.v11), .watchOS(.v4)],
    products: [
        .library(name: "NetworkingX",
                 targets: ["NetworkingX"]),
    ],
    dependencies: [
    ],
    targets: [
        .target(
            name: "NetworkingX",
            dependencies: [],
            path: "Sources"),
        .testTarget(
            name: "NetworkingXTests",
            dependencies: ["NetworkingX"],
            path: "NetworkingXTests"),
    ]
)
