import Foundation

final class SupabaseAuthClient {
    private let supabaseURL: URL
    private let anonKey: String
    private let session: URLSession
    private let decoder: JSONDecoder
    private let encoder: JSONEncoder

    init(supabaseURL: URL, anonKey: String, session: URLSession = .shared) {
        self.supabaseURL = supabaseURL
        self.anonKey = anonKey
        self.session = session

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        self.decoder = decoder

        self.encoder = JSONEncoder()
    }

    func signUp(email: String, password: String) async throws -> SupabaseAuthSession {
        let payload = SupabaseCredentialsRequest(email: email, password: password)
        return try await authRequest(path: "/auth/v1/signup", payload: payload)
    }

    func signIn(email: String, password: String) async throws -> SupabaseAuthSession {
        let payload = SupabaseCredentialsRequest(email: email, password: password)
        return try await authRequest(path: "/auth/v1/token?grant_type=password", payload: payload)
    }

    private func authRequest(path: String, payload: SupabaseCredentialsRequest) async throws -> SupabaseAuthSession {
        let endpoint = supabaseURL.appending(path: path)
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(anonKey, forHTTPHeaderField: "apikey")
        request.httpBody = try encoder.encode(payload)

        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError(message: "Invalid auth response")
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            if let authError = try? decoder.decode(SupabaseAuthError.self, from: data) {
                throw APIError(message: authError.msg)
            }
            throw APIError(message: "Auth request failed with status \(httpResponse.statusCode)")
        }

        return try decoder.decode(SupabaseAuthSession.self, from: data)
    }
}

private struct SupabaseCredentialsRequest: Encodable {
    let email: String
    let password: String
}

private struct SupabaseAuthError: Decodable {
    let msg: String
}
