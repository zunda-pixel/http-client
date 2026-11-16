#if AsyncHTTPClient
  import Foundation
  import HTTPTypes
  import NIOCore
  import NIOHTTP1
  import NIOPosix

  /// An HTTP/1.1 server on 127.0.0.1 that answers like `EchoURLProtocol`, so that the tests send
  /// AsyncHTTPClient's requests over a real connection without the network.
  ///
  /// Its streams let the tests wait for what the server sees. They finish when `run(_:)` returns.
  struct EchoServer: Sendable {
    private let port: Int
    /// Yields each time the head of a request arrives.
    let requests: AsyncStream<Void>
    /// Yields each time the client has read most of a body that doesn't end (for a request with
    /// `X-Echo-Unfinished-Body`), so that the client is receiving the body by then.
    let unfinishedResponses: AsyncStream<Void>
    /// Yields each time a connection to the server closes.
    let closedConnections: AsyncStream<Void>

    /// The URL of `path` (with its query) on this server.
    func url(_ path: String) -> URL {
      URL(string: "http://127.0.0.1:\(port)\(path)")!
    }

    /// Runs `body` with a server, and closes the server when `body` returns.
    static func run(_ body: (EchoServer) async throws -> Void) async throws {
      let (requests, receivedRequest) = AsyncStream.makeStream(of: Void.self)
      let (unfinishedResponses, sentUnfinishedResponse) = AsyncStream.makeStream(of: Void.self)
      let (closedConnections, closedConnection) = AsyncStream.makeStream(of: Void.self)
      let signals = EchoHandler.Signals(
        receivedRequest: receivedRequest,
        sentUnfinishedResponse: sentUnfinishedResponse,
        closedConnection: closedConnection
      )
      defer { signals.finish() }
      let channel = try await ServerBootstrap(group: MultiThreadedEventLoopGroup.singleton)
        .serverChannelOption(.socketOption(.so_reuseaddr), value: 1)
        .childChannelInitializer { channel in
          channel.eventLoop.makeCompletedFuture {
            // Without pipelining assistance: it stops reading while a response is pending, so the
            // server wouldn't see the client close the connection of a request it doesn't answer.
            try channel.pipeline.syncOperations.configureHTTPServerPipeline(
              withPipeliningAssistance: false
            )
            try channel.pipeline.syncOperations.addHandler(EchoHandler(signals: signals))
          }
        }
        .bind(host: "127.0.0.1", port: 0)
        .get()
      let server = EchoServer(
        port: channel.localAddress!.port!,
        requests: requests,
        unfinishedResponses: unfinishedResponses,
        closedConnections: closedConnections
      )
      do {
        try await body(server)
      } catch {
        try? await channel.close()
        throw error
      }
      try await channel.close()
    }
  }

  /// Answers a request with the status of its `X-Echo-Status`; its method, URL, and authorization
  /// in the headers; and its `X-Echo-Body`, or else its body, as the body. It doesn't answer a
  /// request with `X-Echo-No-Response`, and answers a request with `X-Echo-Unfinished-Body` with a
  /// body that doesn't end.
  private final class EchoHandler: ChannelInboundHandler {
    /// The size of the body that doesn't end. Writing it completes only after the client has read
    /// most of it: it's several times the socket buffers of both ends (up to 4 MB each on macOS,
    /// and 4 to 6 MB by default on Linux), and AsyncHTTPClient reads a body only as fast as it's
    /// consumed. Not signalling as soon as the head is written: then the cancellation arrives
    /// before the client has the head.
    private static let unfinishedBodySize = 32 * 1024 * 1024

    typealias InboundIn = HTTPServerRequestPart
    typealias OutboundOut = HTTPServerResponsePart

    /// Where the handler tells the tests what it has seen and done.
    struct Signals: Sendable {
      let receivedRequest: AsyncStream<Void>.Continuation
      let sentUnfinishedResponse: AsyncStream<Void>.Continuation
      let closedConnection: AsyncStream<Void>.Continuation

      func finish() {
        receivedRequest.finish()
        sentUnfinishedResponse.finish()
        closedConnection.finish()
      }
    }

    private let signals: Signals
    private var head: HTTPRequestHead?
    private var body = ByteBuffer()

    init(signals: Signals) {
      self.signals = signals
    }

    func channelRead(context: ChannelHandlerContext, data: NIOAny) {
      switch unwrapInboundIn(data) {
      case .head(let head):
        self.head = head
        body.clear()
        signals.receivedRequest.yield()
      case .body(var part):
        body.writeBuffer(&part)
      case .end:
        guard let head, !head.headers.contains(name: HTTPField.Name.echoNoResponse.rawName) else {
          return
        }
        respond(to: head, context: context)
      }
    }

    func channelInactive(context: ChannelHandlerContext) {
      signals.closedConnection.yield()
      context.fireChannelInactive()
    }

    private func respond(to head: HTTPRequestHead, context: ChannelHandlerContext) {
      let fields = head.headers
      let status = HTTPResponseStatus(
        statusCode: fields.first(name: HTTPField.Name.echoStatus.rawName).flatMap { Int($0) } ?? 200
      )
      let isUnfinished = fields.contains(name: HTTPField.Name.echoUnfinishedBody.rawName)
      let body =
        isUnfinished
        ? ByteBuffer(repeating: 0, count: Self.unfinishedBodySize)
        : fields.first(name: HTTPField.Name.echoBody.rawName).map { ByteBuffer(string: $0) } ?? body
      var headers: HTTPHeaders = [
        HTTPField.Name.echoMethod.rawName: head.method.rawValue,
        HTTPField.Name.echoURL.rawName: "http://\(fields.first(name: "Host") ?? "")\(head.uri)",
        // One byte more than it sends when unfinished, so that the client waits for the rest.
        "Content-Length": String(body.readableBytes + (isUnfinished ? 1 : 0)),
      ]
      if let authorization = fields.first(name: "Authorization") {
        headers.add(name: HTTPField.Name.echoAuthorization.rawName, value: authorization)
      }
      let response = HTTPResponseHead(version: head.version, status: status, headers: headers)
      context.write(wrapOutboundOut(.head(response)), promise: nil)
      guard !isUnfinished else {
        let sent = context.eventLoop.makePromise(of: Void.self)
        sent.futureResult.whenSuccess { [signals] in signals.sentUnfinishedResponse.yield() }
        context.writeAndFlush(wrapOutboundOut(.body(.byteBuffer(body))), promise: sent)
        return
      }
      context.write(wrapOutboundOut(.body(.byteBuffer(body))), promise: nil)
      context.writeAndFlush(wrapOutboundOut(.end(nil)), promise: nil)
    }
  }
#endif
