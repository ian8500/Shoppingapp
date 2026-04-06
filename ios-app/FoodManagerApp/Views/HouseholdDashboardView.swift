import SwiftUI

struct HouseholdDashboardView: View {
    let selectedMembership: HouseholdMembership
    let memberships: [HouseholdMembership]
    @ObservedObject var householdViewModel: HouseholdViewModel
    @ObservedObject var authSessionService: AuthSessionService
    let apiHealthy: Bool

    var body: some View {
        NavigationStack {
            List {
                Section("Current Household") {
                    Text(selectedMembership.householdName)
                        .font(.headline)
                    Text("Role: \(selectedMembership.role.capitalized)")
                        .foregroundStyle(.secondary)
                }

                Section("Household Dashboard") {
                    Label(apiHealthy ? "Backend connected" : "Backend not reachable", systemImage: apiHealthy ? "checkmark.circle.fill" : "exclamationmark.triangle")
                        .foregroundStyle(apiHealthy ? .green : .orange)
                    Text("Invites and permission controls can be layered on this screen next.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
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
