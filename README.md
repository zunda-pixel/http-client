# HTTPClient

[![](https://img.shields.io/endpoint?url=https%3A%2F%2Fswiftpackageindex.com%2Fapi%2Fpackages%2Fzunda-pixel%2Fhttp-client%2Fbadge%3Ftype%3Dswift-versions)](https://swiftpackageindex.com/zunda-pixel/http-client)
[![](https://img.shields.io/endpoint?url=https%3A%2F%2Fswiftpackageindex.com%2Fapi%2Fpackages%2Fzunda-pixel%2Fhttp-client%2Fbadge%3Ftype%3Dplatforms)](https://swiftpackageindex.com/zunda-pixel/http-client)

HTTPClient protocol for API Client Library

An API client takes an `HTTPClientProtocol` instead of a concrete HTTP stack, and the app or
server passes `URLSession` or AsyncHTTPClient's `HTTPClient`. Requests and responses are
[swift-http-types](https://github.com/apple/swift-http-types)' `HTTPRequest` and `HTTPResponse`.

## API client

```swift
import Foundation
import HTTPClient
import HTTPTypes

struct GitHubAPI<HTTPClient: HTTPClientProtocol>: Sendable {
  let token: String
  let httpClient: HTTPClient

  func user(login: String) async throws -> User {
    let request = HTTPRequest(
      method: .get,
      url: URL(string: "https://api.github.com/users/\(login)")!,
      headerFields: [
        .authorization: "Bearer \(token)"
      ]
    )
    let (data, response) = try await httpClient.execute(for: request, from: nil)
    guard response.status.kind == .successful else {
      throw GitHubAPIError.unexpectedStatus(response.status)
    }
    return try JSONDecoder().decode(User.self, from: data)
  }
}

struct User: Decodable {
  let login: String
}

enum GitHubAPIError: Error {
  case unexpectedStatus(HTTPResponse.Status)
}
```

`execute(for:from:)` returns the response whatever its status, and throws only when no response
arrives. `HTTPClientProtocol` refines `Sendable`, so an API client can call one client from many
tasks at once (for example, from the child tasks of a task group).

## URLSession

```swift
import Foundation
import HTTPClient

#if canImport(FoundationNetworking)
  import FoundationNetworking
#endif

let api = GitHubAPI(token: "<#token#>", httpClient: .urlSession(.shared))
let user = try await api.user(login: "zunda-pixel")
```

`URLSession` conforms on macOS 12, iOS 15, watchOS 8, tvOS 15, and visionOS 1 or later, and on
Linux. On Linux, `URLSession` is in FoundationNetworking, so import it to name `URLSession`.

## AsyncHTTPClient

The conformance of AsyncHTTPClient's `HTTPClient` is behind the `AsyncHTTPClient` trait, so that
packages that only use `URLSession` don't fetch or build SwiftNIO. Enable the trait where you
depend on http-client:

```swift
// Package.swift (swift-tools-version: 6.1 or later)
dependencies: [
  .package(
    url: "https://github.com/zunda-pixel/http-client",
    from: "0.5.0",
    traits: ["AsyncHTTPClient"]
  ),
  .package(url: "https://github.com/swift-server/async-http-client", from: "1.33.0"),
],
targets: [
  .target(
    name: "App",
    dependencies: [
      .product(name: "HTTPClient", package: "http-client"),
      .product(name: "AsyncHTTPClient", package: "async-http-client"),
    ]
  )
]
```

```swift
import AsyncHTTPClient
import HTTPClient

let api = GitHubAPI(token: "<#token#>", httpClient: .asyncHTTPClient(.shared))
```

SwiftPM enables a trait for the whole package graph when any package enables it. If you get
http-client through another package (an API client library), add http-client to your own
dependencies with the trait, as above.
