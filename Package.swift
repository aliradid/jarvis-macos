// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Jarvis",
    platforms: [.macOS(.v13)],
    products: [
        .executable(name: "Jarvis", targets: ["JarvisDemo"]),
        .executable(name: "JarvisDemo", targets: ["JarvisDemo"])
    ],
    targets: [
        .executableTarget(name: "JarvisDemo", resources: [.process("Resources")])
    ]
)
