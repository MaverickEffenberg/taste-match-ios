
import Foundation
import SwiftData

final class LocalDataService {
    static let shared = LocalDataService()

    private var container: ModelContainer? = {
        let schema = Schema([UserProfile.self, Recipe.self, MasterIngredient.self,
                             MasterDietTag.self, PendingContent.self])
        return try? ModelContainer(for: schema)
    }()

    private var context: ModelContext? { container?.mainContext }

    private init() {}


    func fetchCurrentUser() -> UserProfile? {
        let descriptor = FetchDescriptor<UserProfile>()
        return try? context?.fetch(descriptor).first
    }

    func upsertUser(_ profile: UserProfile) {
        context?.insert(profile)
        try? context?.save()
    }

    func updateUserProfile(dietTags: [String], blacklist: [String]) {
        guard let user = fetchCurrentUser() else { return }
        user.activeDietTags = dietTags
        user.blacklistedIngredients = blacklist
        try? context?.save()
    }

    func clearCurrentUser() {
        guard let user = fetchCurrentUser() else { return }
        context?.delete(user)
        try? context?.save()
    }


    func fetchSavedRecipes(for user: UserProfile?) -> [Recipe] {
        guard let user else { return [] }
        let descriptor = FetchDescriptor<Recipe>()
        let all = (try? context?.fetch(descriptor)) ?? []
        return all.filter { user.savedPlaylist.contains($0.id) } }

        
        
        

    func saveRecipe(_ recipe: Recipe, for user: UserProfile?) {
        guard let user, !user.savedPlaylist.contains(recipe.id) else { return }
        context?.insert(recipe)
        user.savedPlaylist.append(recipe.id)
        try? context?.save()
    }

    func removeRecipe(_ id: UUID, for user: UserProfile?) {
        guard let user else { return }
        user.savedPlaylist.removeAll { $0 == id }
        try? context?.save()
    }
}

enum MockData {

    static let creatorID = UUID()

    static let recipes: [Recipe] = [
        Recipe(
            title: "Halal Chicken Stir-Fry",
            creatorID: creatorID,
            creatorUsername: "Chef Andi",
            videoURL: "https://example.supabase.co/storage/v1/object/public/videos/stir-fry.mp4",
            thumbnailURL: "https://example.supabase.co/storage/v1/object/public/thumbs/stir-fry.jpg",
            recipeDescription: "Quick 15-minute halal stir-fry using leftover chicken and veggies.",
            dietTags: ["Halal"],
            allergenTags: [],
            ingredients: ["chicken breast", "bell pepper", "garlic", "soy sauce", "sesame oil"]
        ),
        Recipe(
            title: "Vegan Tofu Bowl",
            creatorID: creatorID,
            creatorUsername: "Chef Rina",
            videoURL: "https://example.supabase.co/storage/v1/object/public/videos/tofu-bowl.mp4",
            thumbnailURL: "https://example.supabase.co/storage/v1/object/public/thumbs/tofu-bowl.jpg",
            recipeDescription: "Protein-packed vegan bowl with tofu and fresh greens.",
            dietTags: ["Vegan", "Gluten-Free"],
            allergenTags: ["Soy"],
            ingredients: ["tofu", "spinach", "cucumber", "sesame seeds", "rice"]
        ),
        Recipe(
            title: "Peanut Noodles",
            creatorID: creatorID,
            creatorUsername: "Chef Budi",
            videoURL: "https://example.supabase.co/storage/v1/object/public/videos/peanut-noodles.mp4",
            thumbnailURL: "https://example.supabase.co/storage/v1/object/public/thumbs/peanut.jpg",
            recipeDescription: "Creamy peanut noodles ready in 10 minutes.",
            dietTags: ["Vegan"],
            allergenTags: ["Nuts", "Gluten"],
            ingredients: ["noodles", "peanut butter", "garlic", "soy sauce", "lime", "chili"]
        )
    ]

    static let ingredientNames: [String] = [
        "chicken breast", "beef", "tofu", "eggs", "salmon",
        "garlic", "onion", "bell pepper", "spinach", "tomato",
        "rice", "noodles", "pasta", "bread", "flour",
        "soy sauce", "sesame oil", "olive oil", "butter", "milk",
        "peanut butter", "coconut milk", "curry paste", "lime", "chili"
    ]

    static let masterIngredients: [MasterIngredient] = [
        MasterIngredient(name: "Chicken Breast", category: "Protein", allergenTags: []),
        MasterIngredient(name: "Peanut Butter", category: "Nut-Based", allergenTags: ["Nuts"]),
        MasterIngredient(name: "Tofu", category: "Plant Protein", allergenTags: ["Soy"]),
        MasterIngredient(name: "Wheat Flour", category: "Grain", allergenTags: ["Gluten"])
    ]

    static let masterDietTags: [MasterDietTag] = [
        MasterDietTag(name: "Halal", iconName: "checkmark.seal.fill"),
        MasterDietTag(name: "Vegan", iconName: "leaf.fill"),
        MasterDietTag(name: "Vegetarian", iconName: "carrot.fill"),
        MasterDietTag(name: "Gluten-Free", iconName: "xmark.circle.fill")
    ]

    static let pendingContent: [PendingContent] = [
        PendingContent(recipeID: UUID(), submittedByUserID: UUID())
    ]
}
