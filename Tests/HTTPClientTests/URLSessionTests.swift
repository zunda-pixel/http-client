import Foundation
import HTTPClient
import HTTPTypes
import Testing

#if canImport(FoundationNetworking)
  import FoundationNetworking
#endif

@Suite struct URLSessionTests {
  let session: URLSession = {
    let configuration = URLSessionConfiguration.ephemeral
    configuration.protocolClasses = [EchoURLProtocol.self]
    return URLSession(configuration: configuration)
  }()

  @Test func sendsTheRequestWithoutABody() async throws {
    let request = HTTPRequest(
      method: .get,
      scheme: "https",
      authority: "example.com",
      path: "/users?id=1",
      headerFields: [.authorization: "Bearer token"]
    )

    let (data, response) = try await execute(request, from: nil, with: .urlSession(session))

    #expect(response.status == .ok)
    #expect(response.headerFields[.echoMethod] == "GET")
    #expect(response.headerFields[.echoURL] == "https://example.com/users?id=1")
    #expect(response.headerFields[.echoAuthorization] == "Bearer token")
    #expect(data.isEmpty)
  }

  @Test func uploadsTheBody() async throws {
    let request = HTTPRequest(
      method: .post,
      scheme: "https",
      authority: "example.com",
      path: "/upload"
    )

    let (data, response) = try await execute(
      request,
      from: Data("hello".utf8),
      with: .urlSession(session)
    )

    #expect(response.status == .ok)
    #expect(response.headerFields[.echoMethod] == "POST")
    // swift-corelibs-foundation doesn't hand an uploaded body to a URL protocol, so the stub
    // can echo it only on Apple platforms.
    #if !canImport(FoundationNetworking)
      #expect(String(decoding: data, as: UTF8.self) == "hello")
    #endif
  }

  @Test func returnsAnErrorStatusAsAResponseWithItsBody() async throws {
    var request = HTTPRequest(
      method: .get,
      scheme: "https",
      authority: "example.com",
      path: "/missing"
    )
    request.headerFields[.echoStatus] = "404"
    request.headerFields[.echoBody] = "not found"

    let (data, response) = try await execute(request, from: nil, with: .urlSession(session))

    #expect(response.status == .notFound)
    #expect(String(decoding: data, as: UTF8.self) == "not found")
  }

  @Test func rejectsARequestWithoutAURL() async throws {
    let request = HTTPRequest(method: .get, scheme: nil, authority: nil, path: "/")

    await #expect(throws: (any Error).self) {
      try await execute(request, from: nil, with: .urlSession(session))
    }
  }

  // Swift Testing has no default time limit, so a request that hangs would otherwise keep the
  // test running until CI's job timeout.
  @Test(.timeLimit(.minutes(1)))
  func cancelsTheRequestWhenTheTaskIsCancelled() async throws {
    let request = HTTPRequest(
      method: .get,
      scheme: "https",
      authority: "example.com",
      path: "/slow",
      headerFields: [.echoNoResponse: "1"]
    )
    let session = session

    await withTaskGroup(of: Void.self) { group in
      group.addTask {
        let error = await #expect(throws: URLError.self) {
          try await execute(request, from: nil, with: .urlSession(session))
        }
        #expect(error?.code == .cancelled)
      }
      group.addTask {
        for await _ in EchoURLProtocol.unansweredRequests { return }
      }
      // Cancels the request once the stub has it. Not waiting for the stub alone: a request that
      // ends before it reaches the stub would leave that wait unfinished.
      _ = await group.next()
      group.cancelAll()
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

/// Answers every request without the network: it echoes the method, URL, and authorization in
/// the response headers, and the uploaded body as the response body. It doesn't answer a request
/// with `X-Echo-No-Response`.
private final class EchoURLProtocol: URLProtocol {
  private static let unanswered = AsyncStream.makeStream(of: Void.self)

  /// Yields each time a request with `X-Echo-No-Response` starts loading.
  static var unansweredRequests: AsyncStream<Void> { unanswered.stream }

  override class func canInit(with request: URLRequest) -> Bool { true }

  override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

  override func startLoading() {
    guard request.value(forHTTPHeaderField: HTTPField.Name.echoNoResponse.rawName) == nil else {
      Self.unanswered.continuation.yield()
      return
    }
    let status =
      request.value(forHTTPHeaderField: HTTPField.Name.echoStatus.rawName).flatMap { Int($0) }
      ?? 200
    var headers = [
      HTTPField.Name.echoMethod.rawName: request.httpMethod ?? "",
      HTTPField.Name.echoURL.rawName: request.url?.absoluteString ?? "",
    ]
    headers[HTTPField.Name.echoAuthorization.rawName] = request.value(
      forHTTPHeaderField: "Authorization"
    )
    let response = HTTPURLResponse(
      url: request.url!,
      statusCode: status,
      httpVersion: "HTTP/1.1",
      headerFields: headers
    )!
    client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
    client?.urlProtocol(self, didLoad: body(of: request))
    client?.urlProtocolDidFinishLoading(self)
  }

  override func stopLoading() {}

  /// The `X-Echo-Body` of `request`, or else its uploaded body (which URLSession hands to a URL
  /// protocol as a stream).
  private func body(of request: URLRequest) -> Data {
    if let body = request.value(forHTTPHeaderField: HTTPField.Name.echoBody.rawName) {
      return Data(body.utf8)
    }
    if let body = request.httpBody {
      return body
    }
    guard let stream = request.httpBodyStream else {
      return Data()
    }
    stream.open()
    defer { stream.close() }
    var body = Data()
    var buffer = [UInt8](repeating: 0, count: 1024)
    while stream.hasBytesAvailable {
      let count = stream.read(&buffer, maxLength: buffer.count)
      guard count > 0 else { break }
      body.append(buffer, count: count)
    }
    return body
  }
}
