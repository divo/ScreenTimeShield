// swift-tools-version: 5.9
import PackageDescription

let package = Package(
  name: "UnplugCore",
  products: [
    .library(name: "UnplugCore", targets: ["UnplugCore"]),
  ],
  targets: [
    .target(name: "UnplugCore"),
    .testTarget(name: "UnplugCoreTests", dependencies: ["UnplugCore"]),
  ]
)
