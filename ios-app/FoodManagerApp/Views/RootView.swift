import SwiftUI

struct RootView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        Group {
            if let configErrorMessage = appState.configErrorMessage {
                ContentUnavailableView("Configuration Error", systemImage: "exclamationmark.triangle", description: Text(configErrorMessage))
            } else if let authSessionService = appState.authSessionService,
                      let householdViewModel = appState.householdViewModel,
                      let shoppingListService = appState.shoppingListService,
                      let inventoryService = appState.inventoryService {
                AuthenticationFlowView(
                    authSessionService: authSessionService,
                    householdViewModel: householdViewModel,
                    shoppingListService: shoppingListService,
                    apiHealthy: appState.apiHealthy,
                    inventoryService: inventoryService
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
    let shoppingListService: ShoppingListService
    let apiHealthy: Bool
    let inventoryService: InventoryService

    var body: some View {
        if !authSessionService.isAuthenticated {
            AuthContainerView(authSessionService: authSessionService)
        } else if let selectedMembership = householdViewModel.selectedMembership,
                  let accessToken = authSessionService.session?.accessToken {
            HouseholdDashboardContainerView(
                selectedMembership: selectedMembership,
                memberships: householdViewModel.memberships,
                householdViewModel: householdViewModel,
                authSessionService: authSessionService,
                shoppingListService: shoppingListService,
                accessToken: accessToken,
                apiHealthy: apiHealthy,
                inventoryService: inventoryService
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

private struct HouseholdDashboardContainerView: View {
    let selectedMembership: HouseholdMembership
    let memberships: [HouseholdMembership]
    @ObservedObject var householdViewModel: HouseholdViewModel
    @ObservedObject var authSessionService: AuthSessionService
    let shoppingListService: ShoppingListService
    let accessToken: String
    let apiHealthy: Bool
    let inventoryService: InventoryService

    @StateObject private var shoppingListViewModel: ShoppingListViewModel
    @StateObject private var inventoryViewModel: InventoryViewModel

    init(
        selectedMembership: HouseholdMembership,
        memberships: [HouseholdMembership],
        householdViewModel: HouseholdViewModel,
        authSessionService: AuthSessionService,
        shoppingListService: ShoppingListService,
        accessToken: String,
        apiHealthy: Bool,
        inventoryService: InventoryService
    ) {
        self.selectedMembership = selectedMembership
        self.memberships = memberships
        self.householdViewModel = householdViewModel
        self.authSessionService = authSessionService
        self.shoppingListService = shoppingListService
        self.accessToken = accessToken
        self.apiHealthy = apiHealthy
        self.inventoryService = inventoryService
        _shoppingListViewModel = StateObject(
            wrappedValue: ShoppingListViewModel(
                shoppingService: shoppingListService,
                householdID: selectedMembership.householdID,
                accessToken: accessToken
            )
        )
        _inventoryViewModel = StateObject(
            wrappedValue: InventoryViewModel(
                inventoryService: inventoryService,
                householdID: selectedMembership.householdID,
                accessToken: accessToken
            )
        )
    }

    var body: some View {
        HouseholdDashboardView(
            selectedMembership: selectedMembership,
            memberships: memberships,
            householdViewModel: householdViewModel,
            authSessionService: authSessionService,
            shoppingListViewModel: shoppingListViewModel,
            apiHealthy: apiHealthy,
            inventoryViewModel: inventoryViewModel
        )
    }
}
