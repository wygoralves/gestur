// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "Gestur",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .library(name: "GestureBridgeCore", targets: ["GestureBridgeCore"]),
        .executable(name: "Gestur", targets: ["Gestur"]),
        .executable(name: "GesturValidation", targets: ["GesturValidation"])
    ],
    targets: [
        .target(
            name: "GestureBridgeCore",
            path: "Sources/GestureBridgeCore"
        ),
        .executableTarget(
            name: "Gestur",
            dependencies: ["GestureBridgeCore"],
            path: "Sources/GestureBridge"
        ),
        .executableTarget(
            name: "GesturValidation",
            dependencies: ["GestureBridgeCore"],
            path: "Sources/GestureBridgeValidation"
        )
    ]
)
