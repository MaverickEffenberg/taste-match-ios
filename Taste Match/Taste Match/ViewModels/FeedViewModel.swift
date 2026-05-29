
import Foundation
import Combine

@MainActor
final class FeedViewModel: ObservableObject {

    @Published var visibleRecipes: [Recipe] = []

    @Published var currentIndex: Int = 0

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
            let all = try await recipeService.fetchApprovedRecipes()
            visibleRecipes = applyProfileFilter(to: all)
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    func applyProfileFilter(to recipes: [Recipe]) -> [Recipe] {
        let blacklist = Set(profileViewModel.blacklistedIngredients.map { $0.lowercased() })
        let requiredDietTags = Set(profileViewModel.activeDietTags)

        return recipes.filter { recipe in
            let hasBlacklisted = recipe.ingredients.contains { ingredient in
                blacklist.contains(ingredient.lowercased())
            }
            if hasBlacklisted { return false }

            if !requiredDietTags.isEmpty {
                let recipeDietSet = Set(recipe.dietTags)
                let satisfiesAll = requiredDietTags.isSubset(of: recipeDietSet)
                if !satisfiesAll { return false }
            }
            return true
        }
    }

    func saveRecipe(_ recipe: Recipe) {
        profileViewModel.saveRecipe(recipe)
    }

    func toggleExpansion() {
        isExpanded.toggle()
    }

    var currentRecipe: Recipe? {
        guard !visibleRecipes.isEmpty, currentIndex < visibleRecipes.count else { return nil }
        return visibleRecipes[currentIndex]
    }
}
