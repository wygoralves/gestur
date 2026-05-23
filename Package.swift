// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "GestureBridge",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .library(name: "GestureBridgeCore", targets: ["GestureBridgeCore"]),
        .executable(name: "GestureBridge", targets: ["GestureBridge"]),
        .executable(name: "GestureBridgeValidation", targets: ["GestureBridgeValidation"])
    ],
    targets: [
        .target(
            name: "GestureBridgeCore",
            path: "Sources/GestureBridgeCore"
        ),
        .executableTarget(
            name: "GestureBridge",
            dependencies: ["GestureBridgeCore"],
            path: "Sources/GestureBridge"
        ),
        .executableTarget(
            name: "GestureBridgeValidation",
            dependencies: ["GestureBridgeCore"],
            path: "Sources/GestureBridgeValidation"
        )
    ]
)
