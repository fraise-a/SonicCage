// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "SonicCage",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "SonicCage", targets: ["SonicCage"])
    ],
    dependencies: [
        .package(url: "https://github.com/sparkle-project/Sparkle", exact: "2.9.6")
    ],
    targets: [
        .executableTarget(
            name: "SonicCage",
            dependencies: [
                .product(name: "Sparkle", package: "Sparkle")
            ],
            path: "Sources/SonicCage",
            linkerSettings: [
                .unsafeFlags([
                    "-Xlinker", "-rpath",
                    "-Xlinker", "@executable_path/../Frameworks"
                ])
            ]
        )
    ]
)
