// swift-tools-version: 6.0

import PackageDescription

let package = Package(
  name: "http-client",
  platforms: [
    .macOS(.v10_15),
    .iOS(.v13),
    .watchOS(.v6),
    .tvOS(.v13),
    .visionOS(.v1),
    .macCatalyst(.v14),
  ],
  products: [
    .library(
      name: "HTTPClient",
      targets: ["HTTPClient"]
    ),
    .library(
      name: "HTTPClientFoundation",
      targets: ["HTTPClientFoundation"]
    ),
  ],
  dependencies: [
    .package(url: "https://github.com/apple/swift-http-types", from: "1.3.0"),
  ],
  targets: [
    .target(
      name: "HTTPClient",
      dependencies: [
        .product(name: "HTTPTypes", package: "swift-http-types"),
        .product(name: "HTTPTypesFoundation", package: "swift-http-types"),
      ]
    ),
    .target(
      name: "HTTPClientFoundation",
      dependencies: [
        .target(name: "HTTPClient"),
      ]
    ),
  ]
)
