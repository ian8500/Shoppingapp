import SwiftUI

struct RootView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        Group {
            if let configErrorMessage = appState.configErrorMessage {
                ContentUnavailableView("Configuration Error", systemImage: "exclamationmark.triangle", description: Text(configErrorMessage))
            } else if let authSessionService = appState.authSessionService,
                      let householdViewModel = appState.householdViewModel {
                AuthenticationFlowView(
                    authSessionService: authSessionService,
                    householdViewModel: householdViewModel,
                    apiHealthy: appState.apiHealthy
                )
            } else {
                ProgressView("Loading app configuration")
            }
        }
        .task {
            await appState.performHealthCheck()
            await appState.refreshHouseholdsIfPossible()
        }
    }
}

private struct AuthenticationFlowView: View {
    @ObservedObject var authSessionService: AuthSessionService
    @ObservedObject var householdViewModel: HouseholdViewModel
    let apiHealthy: Bool

    var body: some View {
        if !authSessionService.isAuthenticated {
            AuthContainerView(authSessionService: authSessionService)
        } else if let selectedMembership = householdViewModel.selectedMembership {
            HouseholdDashboardView(
                selectedMembership: selectedMembership,
                memberships: householdViewModel.memberships,
                householdViewModel: householdViewModel,
                authSessionService: authSessionService,
                apiHealthy: apiHealthy
            )
            .task(id: authSessionService.session?.accessToken) {
                await loadMemberships()
            }
        } else {
            HouseholdCreationView(householdViewModel: householdViewModel, authSessionService: authSessionService)
                .task(id: authSessionService.session?.accessToken) {
                    await loadMemberships()
                }
        }
    }

    private func loadMemberships() async {
        guard let accessToken = authSessionService.session?.accessToken else { return }
        await householdViewModel.loadMemberships(accessToken: accessToken)
    }
}
