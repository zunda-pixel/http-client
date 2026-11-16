import Foundation
import HTTPTypes
import HTTPTypesFoundation

#if canImport(FoundationNetworking)
  import FoundationNetworking
#endif

// Calls HTTPTypesFoundation's `data(for:)` and `upload(for:from:)` without a delegate, which
// need only macOS 10.15 and iOS 13. The overloads that take a delegate need macOS 12 and iOS 15,
// so passing one would drop the older systems.
@available(macOS 10.15, iOS 13.0, watchOS 6.0, tvOS 13.0, visionOS 1.0, *)
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

@available(macOS 10.15, iOS 13.0, watchOS 6.0, tvOS 13.0, visionOS 1.0, *)
extension HTTPClientProtocol where Self == URLSession {
  public static func urlSession(_ urlSession: Self) -> Self {
    urlSession
  }
}
