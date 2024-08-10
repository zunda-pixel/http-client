// swift-tools-version: 6.0

import PackageDescription

let package = Package(
  name: "HTTPClient",
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
