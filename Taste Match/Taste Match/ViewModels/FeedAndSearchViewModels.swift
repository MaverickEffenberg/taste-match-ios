import Foundation
import Combine

// MARK: - Feed ViewModel
// Manages the list of recipes shown in the vertical video feed.
// Applies the Global Dietary Profile filter so blacklisted ingredients
// and unmatched diet tags are never displayed to the user.
@MainActor
final class FeedViewModel: ObservableObject {

    // The filtered list actually shown in the feed after profile filtering
    @Published var visibleRecipes: [Recipe] = []

    // Tracks which card index is currently on screen (used by the expansion overlay)
    @Published var currentIndex: Int = 0

    // Controls whether the Dynamic Recipe Expansion overlay is visible
    @Published var isExpanded: Bool = false

    @Published var isLoading: Bool = false
    @Published var errorMessage: String?

    private let recipeService: RecipeServiceProtocol
    private let profileViewModel: ProfileViewModel

    init(recipeService: RecipeServiceProtocol = SupabaseRecipeService(),
         profileViewModel: ProfileViewModel) {
        self.recipeService = recipeService
        self.profileViewModel = profileViewModel
        Task { await loadFeed() }
    }

    func loadFeed() async {
        isLoading = true
        do {
            // Fetch all approved recipes from Supabase then filter locally
            // so the profile check runs instantly without a round-trip.
            let all = try await recipeService.fetchApprovedRecipes()
            visibleRecipes = applyProfileFilter(to: all)
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    // Filters out any recipe that:
    //   (a) contains an ingredient the user has blacklisted, OR
    //   (b) doesn't carry all of the user's required diet tags
    func applyProfileFilter(to recipes: [Recipe]) -> [Recipe] {
        let blacklist = Set(profileViewModel.blacklistedIngredients.map { $0.lowercased() })
        let requiredDietTags = Set(profileViewModel.activeDietTags)

        return recipes.filter { recipe in
            let hasBlacklisted = recipe.ingredients.contains {
                blacklist.contains($0.lowercased())
            }
            if hasBlacklisted { return false }

            if !requiredDietTags.isEmpty {
                let recipeDietSet = Set(recipe.dietTags)
                if !requiredDietTags.isSubset(of: recipeDietSet) { return false }
            }
            return true
        }
    }

    // Delegates save action to ProfileViewModel so the playlist stays in sync
    func saveRecipe(_ recipe: Recipe) {
        profileViewModel.saveRecipe(recipe)
    }

    func toggleExpansion() {
        isExpanded.toggle()
    }

    // Safe accessor for the currently visible recipe
    var currentRecipe: Recipe? {
        guard !visibleRecipes.isEmpty, currentIndex < visibleRecipes.count else { return nil }
        return visibleRecipes[currentIndex]
    }
}

// MARK: - Search ViewModel
// Powers the Ingredient-First Filter Search screen.
// Handles autocomplete suggestions, ingredient basket management,
// ranked result fetching, and profile-based post-filtering.
@MainActor
final class SearchViewModel: ObservableObject {

    // Bound to the text field; drives the autocomplete suggestions pipeline
    @Published var searchQuery: String = ""

    // The "basket" of ingredients the user wants to search with
    @Published var selectedIngredients: [String] = []

    // Recipes returned from Supabase, sorted by ingredient overlap count
    @Published var searchResults: [Recipe] = []

    // Autocomplete options shown below the text field
    @Published var suggestions: [String] = []

    @Published var isSearching: Bool = false
    @Published var errorMessage: String?

    private let recipeService: RecipeServiceProtocol
    private let profileViewModel: ProfileViewModel
    private var cancellables = Set<AnyCancellable>()

    init(recipeService: RecipeServiceProtocol = SupabaseRecipeService(),
         profileViewModel: ProfileViewModel) {
        self.recipeService = recipeService
        self.profileViewModel = profileViewModel
        bindSearchQuery()
    }

    // Subscribes to searchQuery changes and debounces them so Supabase is
    // only queried after the user pauses typing for 300 ms.
    private func bindSearchQuery() {
        $searchQuery
            .debounce(for: .milliseconds(300), scheduler: RunLoop.main)
            .removeDuplicates()
            .sink { [weak self] query in
                Task { await self?.updateSuggestions(for: query) }
            }
            .store(in: &cancellables)
    }

    func updateSuggestions(for query: String) async {
        // Don't bother querying for very short strings to avoid noise
        guard query.count >= 2 else {
            suggestions = []
            return
        }
        do {
            suggestions = try await recipeService.fetchIngredientSuggestions(prefix: query)
        } catch {
            suggestions = []
        }
    }

    // Adds an ingredient to the basket and immediately re-runs the search
    func addIngredient(_ name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty, !selectedIngredients.contains(trimmed) else { return }
        selectedIngredients.append(trimmed)
        searchQuery = ""
        suggestions = []
        Task { await performSearch() }
    }

    // Removes an ingredient from the basket and re-runs the search
    func removeIngredient(_ name: String) {
        selectedIngredients.removeAll { $0 == name }
        Task { await performSearch() }
    }

    func performSearch() async {
        guard !selectedIngredients.isEmpty else {
            searchResults = []
            return
        }
        isSearching = true
        do {
            let candidates = try await recipeService.searchByIngredients(selectedIngredients)

            // Rank results by how many of the user's ingredients each recipe uses.
            // A recipe that uses 4 of the 5 supplied ingredients ranks above one
            // that only uses 1, maximising the "use what you have" goal.
            let scored = candidates
                .map { recipe -> (Recipe, Int) in
                    let matches = recipe.ingredients.filter {
                        selectedIngredients.contains($0)
                    }.count
                    return (recipe, matches)
                }
                .sorted { $0.1 > $1.1 }
                .map { $0.0 }

            // Apply Global Dietary Profile filter on top of the ranked results
            searchResults = applyProfileFilter(to: scored)
        } catch {
            errorMessage = error.localizedDescription
        }
        isSearching = false
    }

    // Same filter logic as FeedViewModel — keeps behaviour consistent
    private func applyProfileFilter(to recipes: [Recipe]) -> [Recipe] {
        let blacklist = Set(profileViewModel.blacklistedIngredients.map { $0.lowercased() })
        let requiredDietTags = Set(profileViewModel.activeDietTags)

        return recipes.filter { recipe in
            let hasBlacklisted = recipe.ingredients.contains {
                blacklist.contains($0.lowercased())
            }
            if hasBlacklisted { return false }
            if !requiredDietTags.isEmpty {
                return requiredDietTags.isSubset(of: Set(recipe.dietTags))
            }
            return true
        }
    }
}
