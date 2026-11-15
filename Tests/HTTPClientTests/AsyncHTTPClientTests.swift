#if AsyncHTTPClient
  import AsyncHTTPClient
  import Foundation
  import HTTPClient
  import HTTPTypes
  import Testing

  @Suite struct AsyncHTTPClientTests {
    @Test func rejectsARequestWithoutAURLBeforeSendingIt() async throws {
      let request = HTTPRequest(method: .get, scheme: nil, authority: nil, path: "/")

      await #expect(throws: URLError(.badURL)) {
        try await execute(request, with: .asyncHTTPClient(.shared))
      }
    }
  }

  /// Calls the client through the protocol, as an API client does.
  private func execute(
    _ request: HTTPRequest,
    with client: some HTTPClientProtocol
  ) async throws -> (Data, HTTPResponse) {
    try await client.execute(for: request, from: nil)
  }
#endif
