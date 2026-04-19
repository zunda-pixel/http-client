// swift-tools-version: 6.1

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
    )
  ],
  dependencies: [
    .package(url: "https://github.com/apple/swift-http-types", from: "1.3.0"),
    .package(url: "https://github.com/swift-server/async-http-client.git", from: "1.33.0"),
  ],
  targets: [
    .target(
      name: "HTTPClient",
      dependencies: [
        .product(
          name: "AsyncHTTPClient",
          package: "async-http-client",
        ),
        .product(name: "HTTPTypes", package: "swift-http-types"),
        .product(name: "HTTPTypesFoundation", package: "swift-http-types"),
      ]
    )
  ]
)
