import Foundation
import Combine
import Auth
import Supabase

// MARK: - AuthViewModel
//
// FIX: "auth session missing" on macOS
//
// Root cause: signInWithOAuth on macOS opens the system browser and returns
// immediately — it does NOT await the redirect callback. Reading
// `supabase.auth.session` right after the call throws "Auth session missing"
// because the OAuth handshake isn't done yet.
//
// Fix: Subscribe to supabase.auth.authStateChanges and update currentUser
// whenever Supabase fires a .signedIn event (i.e. after the redirect URL
// is handled by onOpenURL in FridgeFlixApp). The existing onOpenURL block
// already calls `supabase.auth.session(from:)` which completes the exchange
// and fires the state-change stream — we just need to listen to it here.

@MainActor
final class AuthViewModel: ObservableObject {

    @Published var currentUser: UserProfile?
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?

    private let authService: AuthServiceProtocol
    private let localStore: LocalDataService
    private var authListenerTask: Task<Void, Never>?

    init(authService: AuthServiceProtocol = SupabaseAuthService(),
         localStore: LocalDataService = LocalDataService.shared) {
        self.authService = authService
        self.localStore  = localStore
        startAuthStateListener()
    }

    deinit {
        authListenerTask?.cancel()
    }

    // MARK: - Auth state stream listener
    // This replaces the one-shot `restoreSession()` call.
    // It handles both app-launch session restore AND the post-OAuth callback.

    private func startAuthStateListener() {
        authListenerTask = Task {
            for await (event, session) in supabase.auth.authStateChanges {
                switch event {
                case .initialSession:
                    // App launch: restore cached session if one exists.
                    if let user = session?.user {
                        applySession(user: user)
                    } else {
                        // No live session — try local SwiftData cache.
                        currentUser = localStore.fetchCurrentUser()
                    }

                case .signedIn:
                    // Fires after OAuth redirect is processed by onOpenURL.
                    if let user = session?.user {
                        applySession(user: user)
                    }

                case .signedOut, .userDeleted:
                    currentUser = nil
                    localStore.clearCurrentUser()

                case .tokenRefreshed:
                    // Session refreshed silently — no UI action needed.
                    break

                default:
                    break
                }
            }
        }
    }

    private func applySession(user: Auth.User) {
        let profile = UserProfile(
            id: user.id,
            email: user.email ?? "",
            username: user.email?.components(separatedBy: "@").first ?? "User"
        )
        localStore.upsertUser(profile)
        currentUser = profile
    }

    // MARK: - Sign In
    // On macOS: opens the browser. Session is applied via the authStateChanges
    // stream once the redirect URL lands in onOpenURL → supabase.auth.session(from:).
    // On iOS: the ASWebAuthenticationSession sheet handles the full round-trip.

    func signInWithGoogle() async {
        isLoading = true
        errorMessage = nil
        do {
            try await supabase.auth.signInWithOAuth(
                provider: .google,
                redirectTo: URL(string: "io.tastematch.app://auth/callback")!
            )
            // Do NOT read supabase.auth.session here on macOS —
            // the session arrives via authStateChanges after the redirect.
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    // MARK: - Sign Out

    func signOut() async {
        do {
            try await supabase.auth.signOut()
            // currentUser is cleared by the .signedOut case in the listener.
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    var isAdmin: Bool { currentUser?.isAdmin ?? false }
}
