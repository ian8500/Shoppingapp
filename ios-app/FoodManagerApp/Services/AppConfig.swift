import Foundation

enum AppConfigError: LocalizedError {
    case missingValue(String)
    case invalidURL(String)

    var errorDescription: String? {
        switch self {
        case .missingValue(let key):
            return "Missing required environment variable: \(key)"
        case .invalidURL(let value):
            return "Invalid URL value: \(value)"
        }
    }
}

struct AppConfig {
    let apiBaseURL: URL
    let supabaseURL: URL
    let supabaseAnonKey: String

    static func fromEnvironment() throws -> AppConfig {
        let env = ProcessInfo.processInfo.environment

        guard let apiBaseURLString = env["API_BASE_URL"] else {
            throw AppConfigError.missingValue("API_BASE_URL")
        }
        guard let supabaseURLString = env["SUPABASE_URL"] else {
            throw AppConfigError.missingValue("SUPABASE_URL")
        }
        guard let supabaseAnonKey = env["SUPABASE_ANON_KEY"] else {
            throw AppConfigError.missingValue("SUPABASE_ANON_KEY")
        }
        guard let apiBaseURL = URL(string: apiBaseURLString) else {
            throw AppConfigError.invalidURL(apiBaseURLString)
        }
        guard let supabaseURL = URL(string: supabaseURLString) else {
            throw AppConfigError.invalidURL(supabaseURLString)
        }

        return AppConfig(
            apiBaseURL: apiBaseURL,
            supabaseURL: supabaseURL,
            supabaseAnonKey: supabaseAnonKey
        )
    }
}
