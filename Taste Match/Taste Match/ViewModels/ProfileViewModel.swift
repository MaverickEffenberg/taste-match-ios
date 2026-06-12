import Foundation
import Combine

@MainActor
final class ProfileViewModel: ObservableObject {

    @Published var activeDietTags: [String] = []
    @Published var blacklistedIngredients: [String] = []
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
        loadLocalProfile()
        Task { await syncRemoteProfile() }
    }

    private func loadLocalProfile() {
        guard let user = localStore.fetchCurrentUser() else { return }
        currentUser = user
        activeDietTags = user.activeDietTags
        blacklistedIngredients = user.blacklistedIngredients
        savedRecipes = localStore.fetchSavedRecipes(for: user)
    }

    private func syncRemoteProfile() async {
        guard let remote = try? await profileService.fetchProfile() else { return }
        localStore.upsertUser(remote)
        currentUser = remote
        activeDietTags = remote.activeDietTags
        blacklistedIngredients = remote.blacklistedIngredients

        if !remote.savedPlaylist.isEmpty {
            if let liveRecipes = try? await profileService.fetchSavedRecipesDetails(for: remote.savedPlaylist) {
                savedRecipes = liveRecipes
            }
        } else {
            savedRecipes = []
        }
    }

    func toggleDietTag(_ tag: String) {
        if activeDietTags.contains(tag) {
            activeDietTags.removeAll { $0 == tag }
        } else {
            activeDietTags.append(tag)
        }
        persistProfile()
    }

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

    func toggleSaveRecipe(_ recipe: Recipe) {
        if isSaved(recipe) {
            unsaveRecipe(recipe)
        } else {
            saveRecipe(recipe)
        }
    }

    func saveRecipe(_ recipe: Recipe) {
        guard !savedRecipes.contains(where: { $0.id == recipe.id }) else { return }
        savedRecipes.insert(recipe, at: 0)
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
