import Foundation
import SwiftData

enum UserRole: String, Codable {
    case user    = "user"
    case creator = "creator"
    case admin   = "admin"
}

@Model
final class UserProfile {
    var id: UUID
    var email: String
    var username: String
    var avatarURL: String
    var role: String
    var activeDietTags: [String]
    var blacklistedIngredients: [String]
    var savedPlaylist: [UUID]

    init(
        id: UUID = UUID(),
        email: String,
        username: String,
        avatarURL: String = "",
        role: String = UserRole.user.rawValue,
        activeDietTags: [String] = [],
        blacklistedIngredients: [String] = [],
        savedPlaylist: [UUID] = []
    ) {
        self.id = id
        self.email = email
        self.username = username
        self.avatarURL = avatarURL
        self.role = role
        self.activeDietTags = activeDietTags
        self.blacklistedIngredients = blacklistedIngredients
        self.savedPlaylist = savedPlaylist
    }

    var isAdmin: Bool {
        role.lowercased() == UserRole.admin.rawValue
    }
}
