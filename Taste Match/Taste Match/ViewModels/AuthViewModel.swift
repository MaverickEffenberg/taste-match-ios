
import Foundation
import Combine

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
        currentUser = localStore.fetchCurrentUser()
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
