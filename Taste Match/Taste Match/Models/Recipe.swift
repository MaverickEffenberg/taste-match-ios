
import Foundation
import SwiftData

enum DietTag: String, Codable, CaseIterable, Identifiable {
    case halal     = "Halal"
    case vegan     = "Vegan"
    case vegetarian = "Vegetarian"
    case glutenFree = "Gluten-Free"
    case dairyFree  = "Dairy-Free"

    var id: String { rawValue }
}

enum AllergenTag: String, Codable, CaseIterable, Identifiable {
    case nuts      = "Nuts"
    case gluten    = "Gluten"
    case dairy     = "Dairy"
    case eggs      = "Eggs"
    case shellfish = "Shellfish"
    case soy       = "Soy"
    case fish      = "Fish"

    var id: String { rawValue }
}


struct RecipeStep: Codable, Identifiable {
    var id: UUID = UUID()
    var stepNumber: Int
    var instruction: String
    var durationMinutes: Int?
}

@Model
final class Recipe {
    var id: UUID
    var title: String
    var creatorID: UUID
    var creatorUsername: String
    var videoURL: String
    var thumbnailURL: String
    var recipeDescription: String
    var dietTags: [String]
    var allergenTags: [String]
    var ingredients: [String]
    var steps: Data
    var createdAt: Date

    init(
        id: UUID = UUID(),
        title: String,
        creatorID: UUID,
        creatorUsername: String,
        videoURL: String,
        thumbnailURL: String,
        recipeDescription: String,
        dietTags: [String] = [],
        allergenTags: [String] = [],
        ingredients: [String] = [],
        steps: Data = Data(),
        createdAt: Date = Date()
    ) {
        self.id = id
        self.title = title
        self.creatorID = creatorID
        self.creatorUsername = creatorUsername
        self.videoURL = videoURL
        self.thumbnailURL = thumbnailURL
        self.recipeDescription = recipeDescription
        self.dietTags = dietTags
        self.allergenTags = allergenTags
        self.ingredients = ingredients
        self.steps = steps
        self.createdAt = createdAt
    }

    var decodedSteps: [RecipeStep] {
        (try? JSONDecoder().decode([RecipeStep].self, from: steps)) ?? []
    }
}
