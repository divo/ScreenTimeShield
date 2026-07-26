// swift-tools-version: 5.9
import PackageDescription

let package = Package(
  name: "UnplugCore",
  // Matches the app (iOS 16) and extensions (16.4). macOS is declared only so `swift test` runs
  // natively against the same API availability the app gets.
  platforms: [.iOS(.v16), .macOS(.v13)],
  products: [
    .library(name: "UnplugCore", targets: ["UnplugCore"]),
  ],
  targets: [
    .target(name: "UnplugCore"),
    .testTarget(name: "UnplugCoreTests", dependencies: ["UnplugCore"]),
  ]
)
