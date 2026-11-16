#if AsyncHTTPClient
  import AsyncHTTPClient
  import Foundation
  import HTTPClient
  import HTTPTypes
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
        #expect(response.headerFields[.echoContentLength] == "5")
        #expect(response.headerFields[.echoTransferEncoding] == nil)
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
        // The request has no body framing, neither a length nor chunks.
        #expect(response.headerFields[.echoContentLength] == nil)
        #expect(response.headerFields[.echoTransferEncoding] == nil)
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

        if await expectCancellation(of: request, once: server.requests) {
          // The call threw; the connection closing shows that the request stopped too.
          for await _ in server.closedConnections { break }
        }
      }
    }

    @Test(.timeLimit(.minutes(1)))
    func cancelsTheRequestWhileReceivingTheBody() async throws {
      try await EchoServer.run { server in
        let request = HTTPRequest(
          method: .get,
          url: server.url("/slow-body"),
          headerFields: [.echoUnfinishedBody: "1"]
        )

        if await expectCancellation(of: request, once: server.unfinishedResponses) {
          for await _ in server.closedConnections { break }
        }
      }
    }
  }

  /// Sends `request`, cancels it once `signal` yields, and expects `CancellationError`. Returns
  /// whether `signal` yielded before the request ended.
  ///
  /// Not waiting for `signal` alone: a request that ends before it would leave that wait
  /// unfinished. Then the request's own error fails the test.
  private func expectCancellation(
    of request: HTTPRequest,
    once signal: AsyncStream<Void>
  ) async -> Bool {
    await withTaskGroup(of: Bool.self) { group in
      group.addTask {
        await #expect(throws: CancellationError.self) {
          try await execute(request, from: nil, with: .asyncHTTPClient(.shared))
        }
        return false
      }
      group.addTask {
        for await _ in signal { return true }
        return false
      }
      let signaled = await group.next() ?? false
      group.cancelAll()
      return signaled
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
