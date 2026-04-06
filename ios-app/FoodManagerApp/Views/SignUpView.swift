import SwiftUI

struct SignUpView: View {
    @ObservedObject var authSessionService: AuthSessionService
    @State private var email: String = ""
    @State private var password: String = ""

    var body: some View {
        VStack(spacing: 12) {
            TextField("Email", text: $email)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled(true)
                .keyboardType(.emailAddress)
                .textFieldStyle(.roundedBorder)

            SecureField("Password", text: $password)
                .textFieldStyle(.roundedBorder)

            Button {
                Task {
                    await authSessionService.signUp(email: email, password: password)
                }
            } label: {
                if authSessionService.isLoading {
                    ProgressView()
                } else {
                    Text("Create Account")
                        .frame(maxWidth: .infinity)
                }
            }
            .buttonStyle(.borderedProminent)
            .disabled(authSessionService.isLoading || email.isEmpty || password.isEmpty)

            Text("You can create a household after account creation.")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}
