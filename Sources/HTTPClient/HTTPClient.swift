import Foundation
import HTTPTypes

public protocol HTTPClientProtocol {
  func execute(for request: HTTPRequest, from body: Data?) async throws -> (Data, HTTPResponse)
}
