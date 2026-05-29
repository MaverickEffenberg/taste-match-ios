import Combine
import Foundation

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
        Task { await loadAll() }
    }

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
            if let index = masterIngredients.firstIndex(where: { $0.id == ingredient.id }) {
                masterIngredients[index] = ingredient
            }
            successMessage = "Ingredient updated."
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func deactivateIngredient(_ ingredient: MasterIngredient) async {
        var updated = ingredient
        updated.isActive = false
        await updateIngredient(updated)
    }


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


    func approveContent(_ content: PendingContent) async {
        do {
            try await adminService.updateContentStatus(content.id, status: "approved")
            updateLocalStatus(content.id, status: "approved")
            successMessage = "Recipe approved and published."
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func rejectContent(_ content: PendingContent, note: String) async {
        do {
            try await adminService.updateContentStatus(content.id, status: "rejected", note: note)
            updateLocalStatus(content.id, status: "rejected")
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func updateLocalStatus(_ id: UUID, status: String) {
        if let i = pendingContent.firstIndex(where: { $0.id == id }) {
            pendingContent[i].status = status
        }
    }
}
