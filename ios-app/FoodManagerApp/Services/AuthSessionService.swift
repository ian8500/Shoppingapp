import Foundation

@MainActor
final class AuthSessionService: ObservableObject {
    @Published private(set) var session: SupabaseAuthSession?
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?

    private let authClient: SupabaseAuthClient
    private let storage: UserDefaults
    private let storageKey = "supabase.auth.session"

    init(authClient: SupabaseAuthClient, storage: UserDefaults = .standard) {
        self.authClient = authClient
        self.storage = storage
        self.session = Self.loadSession(from: storage, key: storageKey)
    }

    var isAuthenticated: Bool { session != nil }

    func signUp(email: String, password: String) async {
        await runAuthOperation {
            try await authClient.signUp(email: email, password: password)
        }
    }

    func signIn(email: String, password: String) async {
        await runAuthOperation {
            try await authClient.signIn(email: email, password: password)
        }
    }

    func signOut() {
        session = nil
        errorMessage = nil
        storage.removeObject(forKey: storageKey)
    }

    private func runAuthOperation(_ action: @escaping () async throws -> SupabaseAuthSession) async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            let authSession = try await action()
            session = authSession
            persist(session: authSession)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func persist(session: SupabaseAuthSession) {
        let encoder = JSONEncoder()
        guard let data = try? encoder.encode(session) else { return }
        storage.set(data, forKey: storageKey)
    }

    private static func loadSession(from storage: UserDefaults, key: String) -> SupabaseAuthSession? {
        guard let data = storage.data(forKey: key) else { return nil }
        let decoder = JSONDecoder()
        return try? decoder.decode(SupabaseAuthSession.self, from: data)
    }
}
