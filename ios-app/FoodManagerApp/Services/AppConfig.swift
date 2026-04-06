import Foundation

struct AppConfig {
    let apiBaseURL: URL
    let supabaseURL: URL
    let supabaseAnonKey: String

    static func fromEnvironment() -> AppConfig {
        let env = ProcessInfo.processInfo.environment

        guard
            let apiBaseURLString = env["API_BASE_URL"],
            let apiBaseURL = URL(string: apiBaseURLString),
            let supabaseURLString = env["SUPABASE_URL"],
            let supabaseURL = URL(string: supabaseURLString),
            let supabaseAnonKey = env["SUPABASE_ANON_KEY"]
        else {
            fatalError("Missing required environment variables for app configuration")
        }

        return AppConfig(
            apiBaseURL: apiBaseURL,
            supabaseURL: supabaseURL,
            supabaseAnonKey: supabaseAnonKey
        )
    }
}
