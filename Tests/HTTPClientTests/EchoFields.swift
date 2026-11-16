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

  /// The method the stub received.
  static let echoMethod = Self("X-Echo-Method")!
  /// The URL the stub received.
  static let echoURL = Self("X-Echo-URL")!
  /// The `Authorization` the stub received.
  static let echoAuthorization = Self("X-Echo-Authorization")!
}
