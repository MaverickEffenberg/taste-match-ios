
import Foundation
import Combine
import SwiftData

@MainActor
final class SearchViewModel: ObservableObject {

    @Published var searchQuery: String = ""

    @Published var selectedIngredients: [String] = []

    @Published var searchResults: [Recipe] = []

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

    func addIngredient(_ name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty, !selectedIngredients.contains(trimmed) else { return }
        selectedIngredients.append(trimmed)
        searchQuery = ""
        suggestions = []
        Task { await performSearch() }
    }

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
            let scored = candidates
                .map { recipe -> (Recipe, Int) in
                    let matches = recipe.ingredients.filter { selectedIngredients.contains($0) }.count
                    return (recipe, matches)
                }
                .sorted { $0.1 > $1.1 }
                .map { $0.0 }

            searchResults = applyProfileFilter(to: scored)
        } catch {
            errorMessage = error.localizedDescription
        }
        isSearching = false
    }

    private func applyProfileFilter(to recipes: [Recipe]) -> [Recipe] {
        let blacklist = Set(profileViewModel.blacklistedIngredients.map { $0.lowercased() })
        let requiredDietTags = Set(profileViewModel.activeDietTags)

        return recipes.filter { recipe in
            let hasBlacklisted = recipe.ingredients.contains { blacklist.contains($0.lowercased()) }
            if hasBlacklisted { return false }
            if !requiredDietTags.isEmpty {
                return requiredDietTags.isSubset(of: Set(recipe.dietTags))
            }
            return true
        }
    }
}
