import SwiftUI

struct HouseholdCreationView: View {
    @ObservedObject var householdViewModel: HouseholdViewModel
    @ObservedObject var authSessionService: AuthSessionService
    @State private var householdName: String = ""

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                Text("Create your first household to start managing shared shopping and inventory.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                TextField("Household name", text: $householdName)
                    .textFieldStyle(.roundedBorder)

                Button {
                    Task {
                        guard let token = authSessionService.session?.accessToken else { return }
                        await householdViewModel.createHousehold(name: householdName, accessToken: token)
                    }
                } label: {
                    if householdViewModel.isLoading {
                        ProgressView()
                    } else {
                        Text("Create Household")
                            .frame(maxWidth: .infinity)
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(householdViewModel.isLoading || householdName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

                if let error = householdViewModel.errorMessage {
                    Text(error)
                        .foregroundStyle(.red)
                        .font(.footnote)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding()
            .navigationTitle("New Household")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Sign Out") {
                        authSessionService.signOut()
                        householdViewModel.reset()
                    }
                }
            }
        }
    }
}
