
import Foundation
import Combine
import Auth
import Supabase

@MainActor
final class AuthViewModel: ObservableObject {

    @Published var currentUser: UserProfile?

    @Published var isLoading: Bool = false

    @Published var errorMessage: String?

    private let authService: AuthServiceProtocol
    private let localStore: LocalDataService

    init(authService: AuthServiceProtocol = SupabaseAuthService(),
         localStore: LocalDataService = LocalDataService.shared) {
        self.authService = authService
        self.localStore = localStore
        Task { await restoreSession() }
    }

    private func restoreSession() async {
        // Check live Supabase session first
        if let session = try? await supabase.auth.session {
            let user = session.user
            let profile = UserProfile(
                id: user.id,
                email: user.email ?? "",
                username: user.email?.components(separatedBy: "@").first ?? "User"
            )
            localStore.upsertUser(profile)
            currentUser = profile
        } else {
            // Fall back to local cache
            currentUser = localStore.fetchCurrentUser()
        }
    }

    func signInWithGoogle() async {
        isLoading = true
        errorMessage = nil
        do {
            let profile = try await authService.signInWithGoogle()
            localStore.upsertUser(profile)
            currentUser = profile
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    func signOut() async {
        do {
            try await authService.signOut()
            localStore.clearCurrentUser()
            currentUser = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    var isAdmin: Bool { currentUser?.isAdmin ?? false }
}
