import HTTPTypes

public protocol HTTPClientProtocol: Sendable {
  associatedtype Body
  associatedtype Data
  func execut(_ request: HTTPRequest, body: Body?) async throws -> (Data, HTTPResponse)
}
