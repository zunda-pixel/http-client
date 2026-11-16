import Foundation
import HTTPClient
import HTTPTypes
import Testing

@Suite struct HTTPClientProtocolTests {
  @Test func aGenericAPIClientSharesItsHTTPClientWithChildTasks() async throws {
    let paths = try await executeConcurrently(PathEchoClient(), paths: ["/a", "/b", "/c"])

    #expect(paths.sorted() == ["/a", "/b", "/c"])
  }
}

/// Calls `client` from the child tasks of a task group, as an API client generic over
/// `HTTPClientProtocol` does. It compiles only because the protocol refines `Sendable`.
private func executeConcurrently<Client: HTTPClientProtocol>(
  _ client: Client,
  paths: [String]
) async throws -> [String] {
  try await withThrowingTaskGroup(of: String.self) { group in
    for path in paths {
      group.addTask {
        let request = HTTPRequest(
          method: .get,
          scheme: "https",
          authority: "example.com",
          path: path
        )
        let (data, _) = try await client.execute(for: request, from: nil)
        return String(decoding: data, as: UTF8.self)
      }
    }
    return try await group.reduce(into: []) { $0.append($1) }
  }
}

private struct PathEchoClient: HTTPClientProtocol {
  func execute(for request: HTTPRequest, from body: Data?) async throws -> (Data, HTTPResponse) {
    (Data((request.path ?? "").utf8), HTTPResponse(status: .ok))
  }
}
