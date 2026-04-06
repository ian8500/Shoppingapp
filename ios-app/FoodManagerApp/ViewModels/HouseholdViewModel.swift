import Foundation

@MainActor
final class HouseholdViewModel: ObservableObject {
    @Published private(set) var memberships: [HouseholdMembership] = []
    @Published private(set) var selectedMembership: HouseholdMembership?
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?

    private let apiClient: APIClient

    init(apiClient: APIClient) {
        self.apiClient = apiClient
    }

    func loadMemberships(accessToken: String) async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            let response = try await apiClient.listMemberships(accessToken: accessToken)
            memberships = response.memberships
            if selectedMembership == nil {
                selectedMembership = memberships.first
            } else if let selectedMembership,
                      !memberships.contains(where: { $0.id == selectedMembership.id }) {
                self.selectedMembership = memberships.first
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func createHousehold(name: String, accessToken: String) async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            let response = try await apiClient.createHousehold(name: name, accessToken: accessToken)
            let membership = response.membership
            memberships.insert(membership, at: 0)
            selectedMembership = membership
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func selectMembership(_ membership: HouseholdMembership) {
        selectedMembership = membership
    }

    func reset() {
        memberships = []
        selectedMembership = nil
        isLoading = false
        errorMessage = nil
    }
}
