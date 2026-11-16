// Behind a trait so that the packages that only use URLSession don't build SwiftNIO. SwiftPM 6.2
// or later doesn't fetch it either; SwiftPM 6.1 still resolves and fetches it.
#if AsyncHTTPClient
  import AsyncHTTPClient
  import Foundation
  import HTTPTypes
  // For `HTTPRequest.url`, which is in HTTPTypesFoundation before swift-http-types 1.5.0.
  import HTTPTypesFoundation
  import NIOCore
  import NIOHTTP1

  extension AsyncHTTPClient.HTTPClient: HTTPClientProtocol {
    /// Sends `request` and collects the response body.
    ///
    /// Cancelling the task cancels the request, and then this throws `CancellationError`. A
    /// request without a URL throws `URLError(.badURL)` before it's sent.
    public func execute(
      for request: HTTPTypes.HTTPRequest,
      from body: Data?
    ) async throws -> (Data, HTTPTypes.HTTPResponse) {
      // Not `execute(request:)`: its future doesn't stop the request when the task is cancelled.
      // The deadline is distant because the protocol takes none; the client's configured
      // timeouts still apply, as they did with `execute(request:)`.
      let response = try await self.execute(
        HTTPClientRequest(request: request, body: body),
        deadline: .distantFuture
      )
      let data = try await response.body.collect(upTo: maxResponseBodySize)
      return (Data(data.readableBytesView), HTTPTypes.HTTPResponse(response))
    }
  }

  extension HTTPClientProtocol where Self == AsyncHTTPClient.HTTPClient {
    public static func asyncHTTPClient(_ asyncHTTPClient: Self) -> Self {
      asyncHTTPClient
    }
  }

  /// The most a `ByteBuffer` holds, which was also the limit of `execute(request:)`.
  private let maxResponseBodySize = Int(exactly: UInt32.max) ?? .max

  extension HTTPClientRequest {
    fileprivate init(
      request: HTTPTypes.HTTPRequest,
      body: Data?
    ) throws {
      guard let url = request.url else {
        throw URLError(.badURL)
      }

      self.init(url: url.absoluteString)
      self.method = .init(rawValue: request.method.rawValue)
      self.headers = .init(request.headerFields)
      self.body = body.map { .bytes($0) }
    }
  }

  extension HTTPHeaders {
    fileprivate init(_ fields: HTTPFields) {
      self.init()
      for field in fields {
        self.add(name: field.name.rawName, value: field.value)
      }
    }
  }

  extension HTTPTypes.HTTPResponse {
    fileprivate init(_ response: HTTPClientResponse) {
      self.init(
        status: .init(
          code: Int(response.status.code),
          reasonPhrase: response.status.reasonPhrase
        ),
        headerFields: .init(response.headers)
      )
    }
  }

  extension HTTPFields {
    fileprivate init(_ headers: HTTPHeaders) {
      self.init()
      for header in headers {
        guard let name = HTTPField.Name(header.name) else {
          continue
        }
        self.append(.init(name: name, value: header.value))
      }
    }
  }
#endif
