import Foundation

final class APIClient {
    private let baseURL: URL
    private let session: URLSession

    init(baseURL: URL, session: URLSession = .shared) {
        self.baseURL = baseURL
        self.session = session
    }

    func healthCheck() async throws -> Bool {
        let endpoint = baseURL.appending(path: "/api/v1/health")
        var request = URLRequest(url: endpoint)
        request.httpMethod = "GET"

        let (_, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            return false
        }

        return (200...299).contains(httpResponse.statusCode)
    }
}
