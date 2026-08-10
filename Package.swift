// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "SonicCage",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "SonicCage", targets: ["SonicCage"])
    ],
    targets: [
        .executableTarget(
            name: "SonicCage",
            path: "Sources/SonicCage"
        )
    ]
)
