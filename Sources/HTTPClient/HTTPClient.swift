import Foundation
import HTTPTypes

/// Sends an HTTP request and returns the response body with the response.
///
/// API clients take a value of this type instead of a concrete HTTP stack, so the app or
/// server picks the stack. `URLSession` conforms, and so does `AsyncHTTPClient.HTTPClient`
/// when the `AsyncHTTPClient` trait is enabled.
///
/// Conforming types must be `Sendable`, because API clients call ``execute(for:from:)``
/// concurrently, for example from the child tasks of a task group.
public protocol HTTPClientProtocol: Sendable {
  /// Sends `request`, with `body` when it isn't `nil`, and returns the response body and the
  /// response.
  ///
  /// An error status, such as 4xx or 5xx, doesn't throw: this returns the response whatever its
  /// status. This throws when it can't send the request or can't receive the whole response with
  /// its body, for example when the connection drops, a timeout passes, or redirects loop.
  ///
  /// The errors, and the cases that throw, are those of the conforming type's HTTP stack, so they
  /// differ by conformance. For example:
  ///
  /// - For a request without a URL, `URLSession` throws an error of HTTPTypesFoundation, and
  ///   `AsyncHTTPClient.HTTPClient` throws `URLError(.badURL)`.
  /// - Both cancel the request when the task is cancelled. Then `URLSession` throws
  ///   `URLError(.cancelled)`, and `AsyncHTTPClient.HTTPClient` throws `CancellationError`.
  func execute(for request: HTTPRequest, from body: Data?) async throws -> (Data, HTTPResponse)
}
