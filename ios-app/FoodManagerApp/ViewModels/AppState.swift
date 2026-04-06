import Foundation

@MainActor
final class AppState: ObservableObject {
    @Published var apiHealthy: Bool = false
    @Published var configErrorMessage: String?

    let authSessionService: AuthSessionService?
    let householdViewModel: HouseholdViewModel?

    private let apiClient: APIClient?

    init() {
        do {
            let config = try AppState.loadConfig()
            let apiClient = APIClient(baseURL: config.apiBaseURL)
            let authClient = SupabaseAuthClient(supabaseURL: config.supabaseURL, anonKey: config.supabaseAnonKey)

            self.apiClient = apiClient
            self.authSessionService = AuthSessionService(authClient: authClient)
            self.householdViewModel = HouseholdViewModel(apiClient: apiClient)
            self.configErrorMessage = nil
        } catch {
            self.apiClient = nil
            self.authSessionService = nil
            self.householdViewModel = nil
            self.configErrorMessage = error.localizedDescription
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

    func refreshHouseholdsIfPossible() async {
        guard
            let accessToken = authSessionService?.session?.accessToken,
            let householdViewModel
        else {
            householdViewModel?.reset()
            return
        }

        await householdViewModel.loadMemberships(accessToken: accessToken)
    }

    private static func loadConfig() throws -> AppConfig {
        try AppConfig.fromEnvironment()
    }
}
