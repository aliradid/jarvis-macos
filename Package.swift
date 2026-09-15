// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "JarvisPortfolio",
    platforms: [.macOS(.v13)],
    products: [.executable(name: "JarvisDemo", targets: ["JarvisDemo"])],
    targets: [
        .executableTarget(name: "JarvisDemo", resources: [.process("Resources")])
    ]
)
