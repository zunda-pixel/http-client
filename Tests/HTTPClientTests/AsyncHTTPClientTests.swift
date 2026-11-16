#if AsyncHTTPClient
  import AsyncHTTPClient
  import Foundation
  import HTTPClient
  import HTTPTypes
  // For `HTTPRequest(method:url:headerFields:)`, which is in HTTPTypesFoundation before
  // swift-http-types 1.5.0.
  import HTTPTypesFoundation
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

    // Swift Testing has no default time limit, so a request that hangs would otherwise keep the
    // test running until CI's job timeout.
    @Test(.timeLimit(.minutes(1)))
    func cancelsTheRequestWhenTheTaskIsCancelled() async throws {
      try await EchoServer.run { server in
        let request = HTTPRequest(
          method: .get,
          url: server.url("/slow"),
          headerFields: [.echoNoResponse: "1"]
        )

        await withTaskGroup(of: Void.self) { group in
          group.addTask {
            await #expect(throws: CancellationError.self) {
              try await execute(request, from: nil, with: .asyncHTTPClient(.shared))
            }
          }
          group.addTask {
            for await _ in server.requests { return }
          }
          // Cancels the request once the server has it. Not waiting for the server alone: a
          // request that ends before it reaches the server would leave that wait unfinished.
          _ = await group.next()
          group.cancelAll()
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
