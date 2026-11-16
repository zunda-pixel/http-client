import HTTPTypes

/// The header fields of the stubs that the tests send requests to: `EchoURLProtocol` for
/// URLSession, and `EchoServer` for AsyncHTTPClient.
extension HTTPField.Name {
  /// The status the stub answers with (200 when absent).
  static let echoStatus = Self("X-Echo-Status")!
  /// The body the stub answers with (the request body when absent).
  static let echoBody = Self("X-Echo-Body")!
  /// Makes the stub take the request and never answer it.
  static let echoNoResponse = Self("X-Echo-No-Response")!
  /// Makes the stub send a large body but declare one more byte than it sends, so that the body
  /// never ends (`EchoServer` only).
  static let echoUnfinishedBody = Self("X-Echo-Unfinished-Body")!

  /// The method the stub received.
  static let echoMethod = Self("X-Echo-Method")!
  /// The URL the stub received.
  static let echoURL = Self("X-Echo-URL")!
  /// The `Authorization` the stub received.
  static let echoAuthorization = Self("X-Echo-Authorization")!
  /// The `Content-Length` the stub received (`EchoServer` only).
  static let echoContentLength = Self("X-Echo-Content-Length")!
  /// The `Transfer-Encoding` the stub received (`EchoServer` only).
  static let echoTransferEncoding = Self("X-Echo-Transfer-Encoding")!
  /// Where the `URLRequest` the stub received holds a body, `httpBody` or `httpBodyStream`, and
  /// absent when it holds none (`EchoURLProtocol` only).
  static let echoBodySource = Self("X-Echo-Body-Source")!
}
