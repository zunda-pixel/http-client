import HTTPTypes

public protocol HTTPClientProtocol {
  associatedtype Data
  func execute(for request: HTTPRequest, from body: Data?) async throws -> (Data, HTTPResponse)
}
