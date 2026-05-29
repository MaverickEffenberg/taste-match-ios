
import Foundation
import SwiftData

@Model
final class MasterIngredient {
    var id: UUID
    var name: String
    var category: String
    var allergenTags: [String]
    var isActive: Bool

    init(id: UUID = UUID(), name: String, category: String, allergenTags: [String] = [], isActive: Bool = true) {
        self.id = id
        self.name = name
        self.category = category
        self.allergenTags = allergenTags
        self.isActive = isActive
    }
}

@Model
final class MasterDietTag {
    var id: UUID
    var name: String
    var iconName: String
    var isActive: Bool

    init(id: UUID = UUID(), name: String, iconName: String, isActive: Bool = true) {
        self.id = id
        self.name = name
        self.iconName = iconName
        self.isActive = isActive
    }
}

@Model
final class PendingContent {
    var id: UUID
    var recipeID: UUID
    var submittedByUserID: UUID
    var submittedAt: Date
    var status: String
    var moderatorNote: String

    init(id: UUID = UUID(), recipeID: UUID, submittedByUserID: UUID, status: String = "pending") {
        self.id = id
        self.recipeID = recipeID
        self.submittedByUserID = submittedByUserID
        self.submittedAt = Date()
        self.status = status
        self.moderatorNote = ""
    }
}
