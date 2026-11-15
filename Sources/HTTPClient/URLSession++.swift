import Foundation
import HTTPTypes
import HTTPTypesFoundation

#if canImport(FoundationNetworking)
  import FoundationNetworking
#endif

// The availability is that of HTTPTypesFoundation's async `URLSession` methods. A lower one
// compiles only while the toolchain raises the deployment target above it.
@available(macOS 12.0, iOS 15.0, watchOS 8.0, tvOS 15.0, *)
extension URLSession: HTTPClientProtocol {
  public func execute(
    for request: HTTPRequest,
    from body: Data?
  ) async throws -> (Data, HTTPResponse) {
    if let body {
      try await self.upload(for: request, from: body)
    } else {
      try await self.data(for: request)
    }
  }
}

@available(macOS 12.0, iOS 15.0, watchOS 8.0, tvOS 15.0, *)
extension HTTPClientProtocol where Self == URLSession {
  public static func urlSession(_ urlSession: Self) -> Self {
    urlSession
  }
}
