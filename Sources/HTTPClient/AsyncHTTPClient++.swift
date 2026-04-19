import AsyncHTTPClient
import Foundation
import HTTPTypes
import NIOCore
import NIOHTTP1

extension AsyncHTTPClient.HTTPClient: HTTPClientProtocol {
  public func execute(
    for request: HTTPTypes.HTTPRequest,
    from body: Data?
  ) async throws -> (Data, HTTPTypes.HTTPResponse) {
    let request = try AsyncHTTPClient.HTTPClient.Request(
      request: request,
      body: body
    )
    let response = try await self.execute(request: request).get()
    let data = response.body.map { Data($0.readableBytesView) } ?? Data()
    return (data, HTTPTypes.HTTPResponse(response))
  }
}

extension HTTPClientProtocol where Self == AsyncHTTPClient.HTTPClient {
  public static func asyncHTTPClient(_ asyncHTTPClient: Self) -> Self {
    asyncHTTPClient
  }
}

extension AsyncHTTPClient.HTTPClient.Request {
  fileprivate init(
    request: HTTPRequest,
    body: Data?
  ) throws {
    guard let url = request.url else {
      throw URLError(.badURL)
    }

    self = try Self(
      url: url,
      method: .init(rawValue: request.method.rawValue),
      headers: .init(request.headerFields),
      body: body.map(AsyncHTTPClient.HTTPClient.Body.bytes)
    )
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

extension HTTPResponse {
  fileprivate init(_ response: AsyncHTTPClient.HTTPClient.Response) {
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
