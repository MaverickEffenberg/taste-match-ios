import Combine
import Foundation

// MARK: - Admin ViewModel
// Manages master data (ingredients, diet tags) and content moderation
// for the Admin Dashboard. All mutations go directly to Supabase and
// are reflected immediately in the local published arrays.
@MainActor
final class AdminViewModel: ObservableObject {

    @Published var masterIngredients: [MasterIngredient] = []
    @Published var masterDietTags: [MasterDietTag] = []
    @Published var pendingContent: [PendingContent] = []

    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    @Published var successMessage: String?

    private let adminService: AdminServiceProtocol

    init(adminService: AdminServiceProtocol = SupabaseAdminService()) {
        self.adminService = adminService
        // Load all three datasets in parallel as soon as the view model is created
        Task { await loadAll() }
    }

    // Fetches master ingredients, diet tags, and pending content concurrently
    // using async let so the three network calls run in parallel.
    func loadAll() async {
        isLoading = true
        async let ingredients = adminService.fetchMasterIngredients()
        async let dietTags   = adminService.fetchMasterDietTags()
        async let pending    = adminService.fetchPendingContent()
        do {
            masterIngredients = try await ingredients
            masterDietTags    = try await dietTags
            pendingContent    = try await pending
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    // MARK: Ingredient Management

    // Creates a new ingredient in Supabase and appends it to the local list
    // so the admin sees the change instantly without a full reload.
    func addIngredient(name: String, category: String, allergenTags: [String]) async {
        let ingredient = MasterIngredient(name: name, category: category, allergenTags: allergenTags)
        do {
            try await adminService.createIngredient(ingredient)
            masterIngredients.append(ingredient)
            successMessage = "Ingredient '\(name)' added."
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func updateIngredient(_ ingredient: MasterIngredient) async {
        do {
            try await adminService.updateIngredient(ingredient)
            // Replace the stale copy in the local array with the updated one
            if let index = masterIngredients.firstIndex(where: { $0.id == ingredient.id }) {
                masterIngredients[index] = ingredient
            }
            successMessage = "Ingredient updated."
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // Soft-deletes an ingredient by setting is_active = false.
    // This preserves referential integrity for existing recipes that
    // include the ingredient in their ingredients array.
    func deactivateIngredient(_ ingredient: MasterIngredient) async {
        var updated = ingredient
        updated.isActive = false
        await updateIngredient(updated)
    }

    // MARK: Diet Tag Management

    func addDietTag(name: String, iconName: String) async {
        let tag = MasterDietTag(name: name, iconName: iconName)
        do {
            try await adminService.createDietTag(tag)
            masterDietTags.append(tag)
            successMessage = "Diet tag '\(name)' added."
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // Soft-deletes a diet tag so it no longer appears in user profile toggles
    func deactivateDietTag(_ tag: MasterDietTag) async {
        var updated = tag
        updated.isActive = false
        do {
            try await adminService.updateDietTag(updated)
            if let i = masterDietTags.firstIndex(where: { $0.id == tag.id }) {
                masterDietTags[i] = updated
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: Content Moderation

    // Sets a pending submission to "approved", which should trigger a
    // Supabase DB function/trigger to copy the recipe into the public feed.
    func approveContent(_ content: PendingContent) async {
        do {
            try await adminService.updateContentStatus(content.id, status: "approved")
            updateLocalStatus(content.id, status: "approved")
            successMessage = "Recipe approved and published."
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // Rejects a submission with an optional note explaining the decision,
    // which can be surfaced to the creator in a future notification feature.
    func rejectContent(_ content: PendingContent, note: String) async {
        do {
            try await adminService.updateContentStatus(content.id, status: "rejected", note: note)
            updateLocalStatus(content.id, status: "rejected")
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // Updates the status in the local array to avoid re-fetching from Supabase
    private func updateLocalStatus(_ id: UUID, status: String) {
        if let i = pendingContent.firstIndex(where: { $0.id == id }) {
            pendingContent[i].status = status
        }
    }
}
