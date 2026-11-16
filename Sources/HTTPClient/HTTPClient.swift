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
  /// Returns the response whatever its status, and throws only when no response arrives.
  ///
  /// The errors are those of the conforming type's HTTP stack, so they differ by conformance.
  /// For example, for a request without a URL, `URLSession` throws an error of
  /// HTTPTypesFoundation, and `AsyncHTTPClient.HTTPClient` throws `URLError(.badURL)`.
  func execute(for request: HTTPRequest, from body: Data?) async throws -> (Data, HTTPResponse)
}
