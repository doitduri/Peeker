// swift-tools-version:5.7
import PackageDescription

let package = Package(
    name: "Peeker",
    platforms: [
        .iOS(.v13)
    ],
    products: [
        .library(
            name: "Peeker",
            targets: ["Peeker"]
        )
    ],
    targets: [
        .target(
            name: "Peeker",
            path: "Sources/Peeker"
        ),
        .testTarget(
            name: "PeekerPeekerTests",
            dependencies: ["Peeker"],
            path: "Tests/PeekerTests"
        )
    ]
)

