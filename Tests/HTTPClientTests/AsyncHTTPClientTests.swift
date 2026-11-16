#if AsyncHTTPClient
  import AsyncHTTPClient
  import Foundation
  import HTTPClient
  import HTTPTypes
  import Testing

  @Suite struct AsyncHTTPClientTests {
    @Test func sendsTheMethodHeadersAndBody() async throws {
      try await EchoServer.run { server in
        let request = HTTPRequest(
          method: .post,
          url: server.url("/users?id=1"),
          headerFields: [.authorization: "Bearer token"]
        )

        let (data, response) = try await execute(
          request,
          from: Data("hello".utf8),
          with: .asyncHTTPClient(.shared)
        )

        #expect(response.status == .ok)
        #expect(response.headerFields[.echoMethod] == "POST")
        #expect(response.headerFields[.echoURL] == server.url("/users?id=1").absoluteString)
        #expect(response.headerFields[.echoAuthorization] == "Bearer token")
        #expect(String(decoding: data, as: UTF8.self) == "hello")
      }
    }

    @Test func sendsTheRequestWithoutABody() async throws {
      try await EchoServer.run { server in
        let request = HTTPRequest(method: .get, url: server.url("/users"))

        let (data, response) = try await execute(
          request,
          from: nil,
          with: .asyncHTTPClient(.shared)
        )

        #expect(response.status == .ok)
        #expect(response.headerFields[.echoMethod] == "GET")
        #expect(response.headerFields[.echoAuthorization] == nil)
        #expect(data.isEmpty)
      }
    }

    @Test func returnsAnErrorStatusAsAResponseWithItsReasonPhraseAndBody() async throws {
      try await EchoServer.run { server in
        var request = HTTPRequest(method: .get, url: server.url("/missing"))
        request.headerFields[.echoStatus] = "404"
        request.headerFields[.echoBody] = "not found"

        let (data, response) = try await execute(
          request,
          from: nil,
          with: .asyncHTTPClient(.shared)
        )

        #expect(response.status.code == 404)
        #expect(response.status.reasonPhrase == "Not Found")
        #expect(String(decoding: data, as: UTF8.self) == "not found")
      }
    }

    @Test func rejectsARequestWithoutAURLBeforeSendingIt() async throws {
      let request = HTTPRequest(method: .get, scheme: nil, authority: nil, path: "/")

      await #expect(throws: URLError(.badURL)) {
        try await execute(request, from: nil, with: .asyncHTTPClient(.shared))
      }
    }

    @Test func cancelsTheRequestWhenTheTaskIsCancelled() async throws {
      try await EchoServer.run { server in
        var request = HTTPRequest(method: .get, url: server.url("/slow"))
        request.headerFields[.echoNoResponse] = "1"
        var requests = server.requests.makeAsyncIterator()

        let task = Task {
          try await execute(request, from: nil, with: .asyncHTTPClient(.shared))
        }
        _ = await requests.next()
        task.cancel()

        await #expect(throws: CancellationError.self) {
          try await task.value
        }
      }
    }
  }

  /// Calls the client through the protocol, as an API client does.
  private func execute(
    _ request: HTTPRequest,
    from body: Data?,
    with client: some HTTPClientProtocol
  ) async throws -> (Data, HTTPResponse) {
    try await client.execute(for: request, from: body)
  }
#endif
