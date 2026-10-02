// swift-tools-version: 6.0
import PackageDescription

let package = Package(
  name: "ikc",
  platforms: [.macOS(.v13)],
  products: [.executable(name: "ikc", targets: ["ikc"])],
  targets: [
    .target(name: "IKCCore"),
    .executableTarget(name: "ikc", dependencies: ["IKCCore"]),
    .testTarget(name: "IKCCoreTests", dependencies: ["IKCCore"]),
  ]
)
