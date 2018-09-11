// swift-tools-version:4.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "ThreadSafeSerial",
    products: [
        .library(
            name: "ThreadSafeSerial",
            targets: ["ThreadSafeSerial"]),
    ],
    dependencies: [
        .package(url: "https://github.com/DasenB/SwiftSerial.git", from: "0.0.0")
        
    ],
    targets: [
        .target(
            name: "ThreadSafeSerial",
            dependencies: ["SwiftSerial"]),
        .testTarget(
            name: "ThreadSafeSerialTests",
            dependencies: ["SwiftSerial"]),
    ]
)
