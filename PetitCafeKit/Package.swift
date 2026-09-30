// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PetitCafeKit",
    platforms: [.macOS("26.0")],
    products: [
        .library(name: "PetitCafeKit", targets: ["PetitCafeKit"]),
    ],
    targets: [
        .target(name: "PetitCafeKit"),
        .testTarget(name: "PetitCafeKitTests", dependencies: ["PetitCafeKit"]),
    ]
)
