import SwiftUI

struct HouseholdDashboardView: View {
    let selectedMembership: HouseholdMembership
    let memberships: [HouseholdMembership]
    @ObservedObject var householdViewModel: HouseholdViewModel
    @ObservedObject var authSessionService: AuthSessionService
    @ObservedObject var shoppingListViewModel: ShoppingListViewModel
    @ObservedObject var inventoryViewModel: InventoryViewModel
    let apiHealthy: Bool

    var body: some View {
        TabView {
            NavigationStack {
                ShoppingListView(viewModel: shoppingListViewModel)
            }
            .tabItem {
                Label("Shopping", systemImage: "cart")
            }

            InventoryView(viewModel: inventoryViewModel)
                .tabItem {
                    Label("Inventory", systemImage: "archivebox")
                }

            RecipesView()
                .tabItem {
                    Label("Recipes", systemImage: "book")
                }

            householdHome
                .tabItem {
                    Label("Household", systemImage: "house")
                }
        }
    }

    private var householdHome: some View {
        NavigationStack {
            List {
                Section("Current Household") {
                    Text(selectedMembership.householdName)
                        .font(.headline)
                    Text("Role: \(selectedMembership.role.capitalized)")
                        .foregroundStyle(.secondary)
                }

                Section("System") {
                    Label(apiHealthy ? "Backend connected" : "Backend not reachable", systemImage: apiHealthy ? "checkmark.circle.fill" : "exclamationmark.triangle")
                        .foregroundStyle(apiHealthy ? .green : .orange)
                    Label(shoppingListViewModel.isRealtimeConnected ? "Realtime connected" : "Realtime unavailable", systemImage: shoppingListViewModel.isRealtimeConnected ? "bolt.horizontal.circle.fill" : "bolt.slash")
                        .foregroundStyle(shoppingListViewModel.isRealtimeConnected ? .green : .secondary)
                }

                if memberships.count > 1 {
                    Section("Switch Households") {
                        ForEach(memberships) { membership in
                            Button {
                                householdViewModel.selectMembership(membership)
                            } label: {
                                HStack {
                                    Text(membership.householdName)
                                    Spacer()
                                    if membership.id == selectedMembership.id {
                                        Image(systemName: "checkmark")
                                    }
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Dashboard")
            .toolbar {
                ToolbarItemGroup(placement: .topBarTrailing) {
                    Button("Refresh") {
                        Task {
                            guard let token = authSessionService.session?.accessToken else { return }
                            await householdViewModel.loadMemberships(accessToken: token)
                            await shoppingListViewModel.loadItems()
                        }
                    }

                    Button("Sign Out") {
                        authSessionService.signOut()
                        householdViewModel.reset()
                    }
                }
            }
        }
    }
}
