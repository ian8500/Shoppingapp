import SwiftUI

struct LoginView: View {
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
                    await authSessionService.signIn(email: email, password: password)
                }
            } label: {
                if authSessionService.isLoading {
                    ProgressView()
                } else {
                    Text("Sign In")
                        .frame(maxWidth: .infinity)
                }
            }
            .buttonStyle(.borderedProminent)
            .disabled(authSessionService.isLoading || email.isEmpty || password.isEmpty)
        }
    }
}
