import Foundation
import HTTPClient
import HTTPTypes
import HTTPTypesFoundation

#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

#if os(macOS) || os(iOS) || os(watchOS) || os(tvOS) || os(visionOS) || compiler(>=6.0)

@available(macOS 10.15, iOS 13.0, watchOS 6.0, tvOS 13.0, visionOS 1.0, *)
extension URLSession: HTTPClientProtocol {
  public typealias Body = Foundation.Data
  public typealias Data = Foundation.Data
  
  public func execute(_ request: HTTPTypes.HTTPRequest, body: Data?) async throws -> (Data, HTTPTypes.HTTPResponse) {
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
    return urlSession
  }
}

#endif
