import HTTPTypes

public protocol HTTPClientProtocol: Sendable {
  associatedtype Body
  associatedtype Data
  func execute(for request: HTTPRequest, body: Body?) async throws -> (Data, HTTPResponse)
}
