import Foundation

@MainActor
final class AppState: ObservableObject {
    @Published var selectedTab: AppTab = .shopping
    @Published var apiHealthy: Bool = false

    private let apiClient: APIClient?

    init() {
        let config = try? AppState.loadConfig()
        if let config {
            self.apiClient = APIClient(baseURL: config.apiBaseURL)
        } else {
            self.apiClient = nil
        }
    }

    func performHealthCheck() async {
        guard let apiClient else {
            apiHealthy = false
            return
        }

        do {
            apiHealthy = try await apiClient.healthCheck()
        } catch {
            apiHealthy = false
        }
    }

    private static func loadConfig() throws -> AppConfig {
        AppConfig.fromEnvironment()
    }
}

enum AppTab: Hashable {
    case shopping
    case inventory
    case recipes
}
