# HTTPClient

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

struct GitHubAPI<HTTPClient: HTTPClientProtocol> where HTTPClient.Data == Foundation.Data {
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
