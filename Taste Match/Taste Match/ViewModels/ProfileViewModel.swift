import Foundation
import Combine

@MainActor
final class ProfileViewModel: ObservableObject {

    // Active dietary filters — applied globally to feed and search
    @Published var activeDietTags: [String] = []

    // Ingredients that are always hidden from the user's feed and results
    @Published var blacklistedIngredients: [String] = []

    // Local copy of the user's saved playlist for the Playlist tab
    @Published var savedRecipes: [Recipe] = []

    @Published var isLoading: Bool = false
    @Published var errorMessage: String?

    private let profileService: ProfileServiceProtocol
    private let localStore: LocalDataService
    private var currentUser: UserProfile?

    init(profileService: ProfileServiceProtocol = SupabaseProfileService(),
         localStore: LocalDataService = LocalDataService.shared) {
        self.profileService = profileService
        self.localStore = localStore
        // Load from local cache immediately for instant UI, then sync with
        // the server in the background to pick up any remote changes.
        loadLocalProfile()
        Task { await syncRemoteProfile() }
    }

    // Reads the locally cached profile from SwiftData for instant display
    // while the network request is in flight.
    private func loadLocalProfile() {
        guard let user = localStore.fetchCurrentUser() else { return }
        currentUser = user
        activeDietTags = user.activeDietTags
        blacklistedIngredients = user.blacklistedIngredients
        savedRecipes = localStore.fetchSavedRecipes(for: user)
    }

    // Fetches the authoritative profile from Supabase and updates the local
    // cache and published state with any server-side changes.
    private func syncRemoteProfile() async {
        guard let remote = try? await profileService.fetchProfile() else { return }
        localStore.upsertUser(remote)
        currentUser = remote
        activeDietTags = remote.activeDietTags
        blacklistedIngredients = remote.blacklistedIngredients
        // Refresh saved recipes from the updated local store
        savedRecipes = localStore.fetchSavedRecipes(for: remote)
    }

    // Toggles a single diet tag on or off and persists the change
    func toggleDietTag(_ tag: String) {
        if activeDietTags.contains(tag) {
            activeDietTags.removeAll { $0 == tag }
        } else {
            activeDietTags.append(tag)
        }
        persistProfile()
    }

    // Adds an ingredient to the permanent blacklist after normalising the string
    func addBlacklistedIngredient(_ name: String) {
        let clean = name.trimmingCharacters(in: .whitespaces).lowercased()
        guard !clean.isEmpty, !blacklistedIngredients.contains(clean) else { return }
        blacklistedIngredients.append(clean)
        persistProfile()
    }

    func removeBlacklistedIngredient(_ name: String) {
        blacklistedIngredients.removeAll { $0 == name }
        persistProfile()
    }

    // Saves a recipe locally (SwiftData) and remotely (Supabase) in parallel.
    // Local save is synchronous so the UI updates instantly.
    func saveRecipe(_ recipe: Recipe) {
        guard !savedRecipes.contains(where: { $0.id == recipe.id }) else { return }
        savedRecipes.append(recipe)
        localStore.saveRecipe(recipe, for: currentUser)
        Task { try? await profileService.saveRecipe(recipe.id) }
    }

    func unsaveRecipe(_ recipe: Recipe) {
        savedRecipes.removeAll { $0.id == recipe.id }
        localStore.removeRecipe(recipe.id, for: currentUser)
        Task { try? await profileService.unsaveRecipe(recipe.id) }
    }

    func isSaved(_ recipe: Recipe) -> Bool {
        savedRecipes.contains { $0.id == recipe.id }
    }

    // Writes dietary preferences to SwiftData first (instant), then
    // syncs asynchronously to Supabase in the background.
    private func persistProfile() {
        localStore.updateUserProfile(dietTags: activeDietTags, blacklist: blacklistedIngredients)
        Task {
            try? await profileService.updateProfile(
                dietTags: activeDietTags,
                blacklist: blacklistedIngredients
            )
        }
    }
}
