import SwiftUI

struct AuthContainerView: View {
    @ObservedObject var authSessionService: AuthSessionService
    @State private var mode: Mode = .signIn

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                Picker("Mode", selection: $mode) {
                    Text("Sign In").tag(Mode.signIn)
                    Text("Sign Up").tag(Mode.signUp)
                }
                .pickerStyle(.segmented)

                if mode == .signIn {
                    LoginView(authSessionService: authSessionService)
                } else {
                    SignUpView(authSessionService: authSessionService)
                }

                if let errorMessage = authSessionService.errorMessage {
                    Text(errorMessage)
                        .foregroundStyle(.red)
                        .font(.footnote)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding()
            .navigationTitle("Welcome")
        }
    }
}

private enum Mode {
    case signIn
    case signUp
}
