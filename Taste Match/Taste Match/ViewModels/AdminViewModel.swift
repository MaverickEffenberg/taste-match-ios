import Foundation
import Combine
import Supabase

@MainActor
final class AdminViewModel: ObservableObject {

    @Published var allRecipes: [Recipe] = []
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    @Published var successMessage: String?

    init() {
        Task { await loadAllRecipes() }
    }

    func loadAllRecipes() async {
        isLoading = true
        errorMessage = nil
        do {
            let response: [RecipeDTO] = try await supabase
                .from("recipes")
                .select()
                .order("created_at", ascending: false)
                .execute()
                .value
            allRecipes = response.map { $0.toRecipe() }
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    func deleteRecipe(_ recipe: Recipe) async {
        do {
            try await supabase
                .from("recipes")
                .delete()
                .eq("id", value: recipe.id.uuidString)
                .execute()
            
            allRecipes.removeAll { $0.id == recipe.id }
            successMessage = "Resep '\(recipe.title)' berhasil dihapus"
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
