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

    private func startAuthStateListener() {
        authListenerTask = Task {
            for await (event, session) in supabase.auth.authStateChanges {
                switch event {
                case .initialSession:
                    if let user = session?.user {
                        applySession(user: user)
                    } else {
                        currentUser = localStore.fetchCurrentUser()
                    }
                case .signedIn:
                    if let user = session?.user {
                        applySession(user: user)
                    }
                case .signedOut, .userDeleted:
                    currentUser = nil
                    localStore.clearCurrentUser()
                case .tokenRefreshed:
                    break
                default:
                    break
                }
            }
        }
    }

    private func applySession(user: Auth.User) {
        Task {
            let profileService = SupabaseProfileService()
            do {
                // SUNTIKAN SUPERIOR: Membuka bungkus Optional dengan elegan
                if let remoteProfile = try await profileService.fetchProfile() {
                    localStore.upsertUser(remoteProfile)
                    currentUser = remoteProfile
                    print("DEBUG: Sukses! Role user adalah: \(remoteProfile.role)")
                } else {
                    // Jika profil belum ada di database, lemparkan error agar masuk ke fallback
                    throw NSError(domain: "Auth", code: 404, userInfo: [NSLocalizedDescriptionKey: "Profil tidak ditemukan di database"])
                }
            } catch {
                print("DEBUG: Gagal sinkronisasi, menggunakan fallback. Error: \(error.localizedDescription)")
                
                // Fallback dengan role default 'user'
                let profile = UserProfile(
                    id: user.id,
                    email: user.email ?? "",
                    username: user.email?.components(separatedBy: "@").first ?? "User",
                    role: UserRole.user.rawValue
                )
                localStore.upsertUser(profile)
                currentUser = profile
            }
        }
    }

    // MARK: - Sign In

    func signInWithGoogle() async {
        isLoading = true
        errorMessage = nil
        do {
            try await supabase.auth.signInWithOAuth(
                provider: .google,
                redirectTo: URL(string: "io.tastematch.app://auth/callback")!,
                queryParams: [(name: "prompt", value: "select_account")]
            )
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    // MARK: - Sign Out

    func signOut() async {
        do {
            try await supabase.auth.signOut()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    var isAdmin: Bool { currentUser?.isAdmin ?? false }
}
