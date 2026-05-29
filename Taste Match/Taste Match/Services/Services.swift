
import Foundation

protocol AuthServiceProtocol {
    func signInWithGoogle() async throws -> UserProfile
    func signOut() async throws
}

protocol RecipeServiceProtocol {
    func fetchApprovedRecipes() async throws -> [Recipe]
    func searchByIngredients(_ ingredients: [String]) async throws -> [Recipe]
    func fetchIngredientSuggestions(prefix: String) async throws -> [String]
}

protocol ProfileServiceProtocol {
    func updateProfile(dietTags: [String], blacklist: [String]) async throws
    func saveRecipe(_ recipeID: UUID) async throws
    func unsaveRecipe(_ recipeID: UUID) async throws
}

protocol AdminServiceProtocol {
    func fetchMasterIngredients() async throws -> [MasterIngredient]
    func fetchMasterDietTags() async throws -> [MasterDietTag]
    func fetchPendingContent() async throws -> [PendingContent]
    func createIngredient(_ ingredient: MasterIngredient) async throws
    func updateIngredient(_ ingredient: MasterIngredient) async throws
    func createDietTag(_ tag: MasterDietTag) async throws
    func updateDietTag(_ tag: MasterDietTag) async throws
    func updateContentStatus(_ id: UUID, status: String, note: String) async throws
}

extension AdminServiceProtocol {
    func updateContentStatus(_ id: UUID, status: String, note: String = "") async throws {
        try await updateContentStatus(id, status: status, note: note)
    }
}

final class SupabaseAuthService: AuthServiceProtocol {
    func signInWithGoogle() async throws -> UserProfile {
        return UserProfile(email: "demo@example.com", username: "DemoUser")
    }

    func signOut() async throws {
    }
}

final class SupabaseRecipeService: RecipeServiceProtocol {

    func fetchApprovedRecipes() async throws -> [Recipe] {
        return MockData.recipes
    }

    func searchByIngredients(_ ingredients: [String]) async throws -> [Recipe] {
        return MockData.recipes.filter { recipe in
            recipe.ingredients.contains { ingredients.contains($0) }
        }
    }

    func fetchIngredientSuggestions(prefix: String) async throws -> [String] {
        return MockData.ingredientNames.filter { $0.lowercased().hasPrefix(prefix.lowercased()) }
    }
}

final class SupabaseProfileService: ProfileServiceProtocol {
    func updateProfile(dietTags: [String], blacklist: [String]) async throws {}
    func saveRecipe(_ recipeID: UUID) async throws {}
    func unsaveRecipe(_ recipeID: UUID) async throws {}
}

final class SupabaseAdminService: AdminServiceProtocol {
    func fetchMasterIngredients() async throws -> [MasterIngredient] { MockData.masterIngredients }
    func fetchMasterDietTags() async throws -> [MasterDietTag] { MockData.masterDietTags }
    func fetchPendingContent() async throws -> [PendingContent] { MockData.pendingContent }
    func createIngredient(_ ingredient: MasterIngredient) async throws {}
    func updateIngredient(_ ingredient: MasterIngredient) async throws {}
    func createDietTag(_ tag: MasterDietTag) async throws {}
    func updateDietTag(_ tag: MasterDietTag) async throws {}
    func updateContentStatus(_ id: UUID, status: String, note: String) async throws {}
}
