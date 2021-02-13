// swift-tools-version:5.3
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "swift-url-benchmark",
    products: [
        .executable(name: "WebURLBenchmark", targets: ["WebURLBenchmark"])
    ],
    dependencies: [
      .package(path: "../swift-url")
    ],
    targets: [
      .target(name: "WebURLBenchmark", dependencies: [.product(name: "WebURL", package: "swift-url")])
    ]
)
