#if AsyncHTTPClient
  import Foundation
  import HTTPTypes
  import NIOCore
  import NIOHTTP1
  import NIOPosix

  /// An HTTP/1.1 server on 127.0.0.1 that answers like `EchoURLProtocol`, so that the tests send
  /// AsyncHTTPClient's requests over a real connection without the network.
  struct EchoServer: Sendable {
    private let port: Int
    /// Yields each time the head of a request arrives.
    let requests: AsyncStream<Void>

    /// The URL of `path` (with its query) on this server.
    func url(_ path: String) -> URL {
      URL(string: "http://127.0.0.1:\(port)\(path)")!
    }

    /// Runs `body` with a server, and closes the server when `body` returns.
    static func run(_ body: (EchoServer) async throws -> Void) async throws {
      let (requests, received) = AsyncStream.makeStream(of: Void.self)
      let channel = try await ServerBootstrap(group: MultiThreadedEventLoopGroup.singleton)
        .serverChannelOption(.socketOption(.so_reuseaddr), value: 1)
        .childChannelInitializer { channel in
          channel.eventLoop.makeCompletedFuture {
            try channel.pipeline.syncOperations.configureHTTPServerPipeline()
            try channel.pipeline.syncOperations.addHandler(EchoHandler(received: received))
          }
        }
        .bind(host: "127.0.0.1", port: 0)
        .get()
      do {
        try await body(EchoServer(port: channel.localAddress!.port!, requests: requests))
      } catch {
        try? await channel.close()
        throw error
      }
      try await channel.close()
    }
  }

  /// Answers a request with the status of its `X-Echo-Status`; its method, URL, and authorization
  /// in the headers; and its `X-Echo-Body`, or else its body, as the body. It doesn't answer a
  /// request with `X-Echo-No-Response`.
  private final class EchoHandler: ChannelInboundHandler {
    typealias InboundIn = HTTPServerRequestPart
    typealias OutboundOut = HTTPServerResponsePart

    private let received: AsyncStream<Void>.Continuation
    private var head: HTTPRequestHead?
    private var body = ByteBuffer()

    init(received: AsyncStream<Void>.Continuation) {
      self.received = received
    }

    func channelRead(context: ChannelHandlerContext, data: NIOAny) {
      switch unwrapInboundIn(data) {
      case .head(let head):
        self.head = head
        body.clear()
        received.yield()
      case .body(var part):
        body.writeBuffer(&part)
      case .end:
        guard let head, !head.headers.contains(name: HTTPField.Name.echoNoResponse.rawName) else {
          return
        }
        respond(to: head, context: context)
      }
    }

    private func respond(to head: HTTPRequestHead, context: ChannelHandlerContext) {
      let fields = head.headers
      let status = HTTPResponseStatus(
        statusCode: fields.first(name: HTTPField.Name.echoStatus.rawName).flatMap { Int($0) } ?? 200
      )
      let body =
        fields.first(name: HTTPField.Name.echoBody.rawName).map { ByteBuffer(string: $0) } ?? body
      var headers: HTTPHeaders = [
        HTTPField.Name.echoMethod.rawName: head.method.rawValue,
        HTTPField.Name.echoURL.rawName: "http://\(fields.first(name: "Host") ?? "")\(head.uri)",
        "Content-Length": String(body.readableBytes),
      ]
      if let authorization = fields.first(name: "Authorization") {
        headers.add(name: HTTPField.Name.echoAuthorization.rawName, value: authorization)
      }
      let response = HTTPResponseHead(version: head.version, status: status, headers: headers)
      context.write(wrapOutboundOut(.head(response)), promise: nil)
      context.write(wrapOutboundOut(.body(.byteBuffer(body))), promise: nil)
      context.writeAndFlush(wrapOutboundOut(.end(nil)), promise: nil)
    }
  }
#endif
