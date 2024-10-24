# HTTPClient

[![](https://img.shields.io/endpoint?url=https%3A%2F%2Fswiftpackageindex.com%2Fapi%2Fpackages%2Fzunda-pixel%2Fhttp-client%2Fbadge%3Ftype%3Dswift-versions)](https://swiftpackageindex.com/zunda-pixel/http-client)
[![](https://img.shields.io/endpoint?url=https%3A%2F%2Fswiftpackageindex.com%2Fapi%2Fpackages%2Fzunda-pixel%2Fhttp-client%2Fbadge%3Ftype%3Dplatforms)](https://swiftpackageindex.com/zunda-pixel/http-client)

HTTPClient protocol for API Client Library

```swift
import HTTPClient
import HTTPClientFoundation
import Foundation

let api = GitHubAPI(
  token: <#GITHUB_TOKEN#>,
  httpClient: .urlSession(.shared)
)

let user = api.user(id: <#user_id#>)

struct GitHubAPI<HTTPClient: HTTPClientProtocol> {
  let token: String
  let httpClient: HTTPClient

  func user(id: String) async throws -> User {
    let request = HTTPRequest(
      method: .get,
      url: url,
      headerFields: [
        .authorization: token
      ]
    )
    let (data, response) = try await httpClient.execut(request, body: nil)
    let user = try JSONDecoder().decode(User.self, from: data)
    return user
  }
}
```
