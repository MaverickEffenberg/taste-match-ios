import Foundation
import Supabase

// Shared Supabase client — single instance used by every service in the app.
// IMPORTANT: the URL must be the bare project base URL, NOT the REST endpoint.
// Using /rest/v1/ here breaks auth, storage, and realtime entirely.
let supabase = SupabaseClient(
    supabaseURL: URL(string: "https://ainrjrzdmblhhfylwrbd.supabase.co")!,
    supabaseKey: "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImFpbnJqcnpkbWJsaGhmeWx3cmJkIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODAwMDI1MjUsImV4cCI6MjA5NTU3ODUyNX0.oYRUBqCMlkqW6XwFdRG_wYk_2No_ClO3mKlMpkr3keo"
)

// MARK: - Service Protocols
// Protocols allow easy swapping with mock implementations during testing.

protocol AuthServiceProtocol {
    func signInWithGoogle() async throws -> UserProfile
    func signOut() async throws
    func currentSession() async throws -> UserProfile?
}

protocol RecipeServiceProtocol {
    func fetchApprovedRecipes() async throws -> [Recipe]
    func searchByIngredients(_ ingredients: [String]) async throws -> [Recipe]
    func fetchIngredientSuggestions(prefix: String) async throws -> [String]
}

protocol ProfileServiceProtocol {
    func fetchProfile() async throws -> UserProfile?
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
    // Default parameter so callers can omit `note` when approving content
    func updateContentStatus(_ id: UUID, status: String, note: String = "") async throws {
        try await updateContentStatus(id, status: status, note: note)
    }
}

// MARK: - DTOs
// These structs mirror the exact column names in Supabase and are decoded
// directly from the JSON response. They are then mapped to domain models.

struct RecipeDTO: Decodable {
    let id: UUID
    let title: String
    let creatorId: UUID
    let creatorUsername: String
    let videoUrl: String
    let thumbnailUrl: String
    let recipeDescription: String
    let dietTags: [String]
    let allergenTags: [String]
    let ingredients: [String]
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id, title
        case creatorId          = "creator_id"
        case creatorUsername    = "creator_username"
        case videoUrl           = "video_url"
        case thumbnailUrl       = "thumbnail_url"
        case recipeDescription  = "recipe_description"
        case dietTags           = "diet_tags"
        case allergenTags       = "allergen_tags"
        case ingredients
        case createdAt          = "created_at"
    }

    func toRecipe() -> Recipe {
        Recipe(
            id: id,
            title: title,
            creatorID: creatorId,
            creatorUsername: creatorUsername,
            videoURL: videoUrl,
            thumbnailURL: thumbnailUrl,
            recipeDescription: recipeDescription,
            dietTags: dietTags,
            allergenTags: allergenTags,
            ingredients: ingredients,
            createdAt: createdAt
        )
    }
}

struct ProfileDTO: Decodable {
    let id: UUID
    let username: String
    let avatarUrl: String
    let role: String
    let activeDietTags: [String]
    let blacklistedIngredients: [String]
    let savedPlaylist: [UUID]

    enum CodingKeys: String, CodingKey {
        case id, username, role
        case avatarUrl                = "avatar_url"
        case activeDietTags           = "active_diet_tags"
        case blacklistedIngredients   = "blacklisted_ingredients"
        case savedPlaylist            = "saved_playlist"
    }
}

// MARK: - Auth Service

final class SupabaseAuthService: AuthServiceProtocol {

    func signInWithGoogle() async throws -> UserProfile {
        // redirectTo must match:
        //   1. The custom URL scheme registered in Info.plist (CFBundleURLTypes)
        //   2. The redirect URL added in Supabase Dashboard → Auth → URL Configuration
        //   3. The authorized redirect URI in Google Cloud Console (the Supabase callback URL)
        try await supabase.auth.signInWithOAuth(
            provider: .google,
            redirectTo: URL(string: "io.tastematch.app://auth/callback")!
        )
        return try await buildProfileFromSession()
    }

    func signOut() async throws {
        try await supabase.auth.signOut()
    }

    // Called on launch to restore a previously authenticated session
    // without requiring the user to log in again.
    func currentSession() async throws -> UserProfile? {
        guard let _ = try? await supabase.auth.session else { return nil }
        return try? await buildProfileFromSession()
    }

    // Pulls the Supabase auth user and merges it with the profiles table
    // to get role and dietary preferences stored server-side.
    private func buildProfileFromSession() async throws -> UserProfile {
        let user = try await supabase.auth.session.user

        // Try to load the extended profile row from the profiles table.
        // Fall back to a minimal profile if the row doesn't exist yet
        // (e.g. first sign-in before the DB trigger creates the row).
        struct ProfileRow: Decodable {
            let username: String?
            let avatarUrl: String?
            let role: String?
            let activeDietTags: [String]?
            let blacklistedIngredients: [String]?
            let savedPlaylist: [UUID]?
            enum CodingKeys: String, CodingKey {
                case username
                case avatarUrl              = "avatar_url"
                case role
                case activeDietTags         = "active_diet_tags"
                case blacklistedIngredients = "blacklisted_ingredients"
                case savedPlaylist          = "saved_playlist"
            }
        }

        let rows: [ProfileRow] = (try? await supabase
            .from("profiles")
            .select()
            .eq("id", value: user.id)
            .limit(1)
            .execute()
            .value) ?? []

        let row = rows.first
        let fallbackUsername = user.email?.components(separatedBy: "@").first ?? "User"

        return UserProfile(
            id: user.id,
            email: user.email ?? "",
            username: row?.username ?? fallbackUsername,
            avatarURL: row?.avatarUrl ?? "",
            role: row?.role ?? UserRole.user.rawValue,
            activeDietTags: row?.activeDietTags ?? [],
            blacklistedIngredients: row?.blacklistedIngredients ?? [],
            savedPlaylist: row?.savedPlaylist ?? []
        )
    }
}

// MARK: - Recipe Service

final class SupabaseRecipeService: RecipeServiceProtocol {

    // Fetches only admin-approved recipes so unapproved creator uploads
    // never appear in the public feed.
    func fetchApprovedRecipes() async throws -> [Recipe] {
        let response: [RecipeDTO] = try await supabase
            .from("recipes")
            .select()
            .eq("is_approved", value: true)
            .execute()
            .value
        return response.map { $0.toRecipe() }
    }

    // Returns recipes that contain at least one of the supplied ingredients.
    // The overlaps operator maps to the PostgreSQL && array operator.
    func searchByIngredients(_ ingredients: [String]) async throws -> [Recipe] {
        let response: [RecipeDTO] = try await supabase
            .from("recipes")
            .select()
            .overlaps("ingredients", value: ingredients)
            .execute()
            .value
        return response.map { $0.toRecipe() }
    }

    // Powers the autocomplete dropdown in the search bar.
    // ilike performs a case-insensitive prefix match.
    func fetchIngredientSuggestions(prefix: String) async throws -> [String] {
        struct IngredientName: Decodable { let name: String }
        let response: [IngredientName] = try await supabase
            .from("master_ingredients")
            .select("name")
            .ilike("name", value: "\(prefix)%")
            .limit(10)
            .execute()
            .value
        return response.map { $0.name }
    }
}

// MARK: - Profile Service

final class SupabaseProfileService: ProfileServiceProtocol {

    // Loads the user's full profile including saved playlist from Supabase,
    // used to hydrate ProfileViewModel with server-side data on launch.
    func fetchProfile() async throws -> UserProfile? {
        let user = try await supabase.auth.session.user

        struct ProfileRow: Decodable {
            let id: UUID
            let username: String
            let avatarUrl: String
            let role: String
            let activeDietTags: [String]
            let blacklistedIngredients: [String]
            let savedPlaylist: [UUID]
            enum CodingKeys: String, CodingKey {
                case id, username, role
                case avatarUrl              = "avatar_url"
                case activeDietTags         = "active_diet_tags"
                case blacklistedIngredients = "blacklisted_ingredients"
                case savedPlaylist          = "saved_playlist"
            }
        }

        let rows: [ProfileRow] = try await supabase
            .from("profiles")
            .select()
            .eq("id", value: user.id)
            .limit(1)
            .execute()
            .value

        guard let row = rows.first else { return nil }

        return UserProfile(
            id: row.id,
            email: user.email ?? "",
            username: row.username,
            avatarURL: row.avatarUrl,
            role: row.role,
            activeDietTags: row.activeDietTags,
            blacklistedIngredients: row.blacklistedIngredients,
            savedPlaylist: row.savedPlaylist
        )
    }

    // Persists the Global Dietary Profile back to Supabase so it is
    // consistent across all user devices.
    func updateProfile(dietTags: [String], blacklist: [String]) async throws {
        let userID = try await supabase.auth.session.user.id
        struct ProfileUpdate: Encodable {
            let active_diet_tags: [String]
            let blacklisted_ingredients: [String]
        }
        try await supabase
            .from("profiles")
            .update(ProfileUpdate(
                active_diet_tags: dietTags,
                blacklisted_ingredients: blacklist
            ))
            .eq("id", value: userID)
            .execute()
    }

    // Calls a Postgres RPC function to atomically append the recipe UUID
    // to the user's saved_playlist array column.
    func saveRecipe(_ recipeID: UUID) async throws {
        let userID = try await supabase.auth.session.user.id
        struct SaveParams: Encodable {
            let user_id: String
            let recipe_id: String
        }
        try await supabase
            .rpc("append_saved_recipe", params: SaveParams(
                user_id: userID.uuidString,
                recipe_id: recipeID.uuidString
            ))
            .execute()
    }

    // Calls a Postgres RPC function to atomically remove the recipe UUID
    // from the user's saved_playlist array column.
    func unsaveRecipe(_ recipeID: UUID) async throws {
        let userID = try await supabase.auth.session.user.id
        struct RemoveParams: Encodable {
            let user_id: String
            let recipe_id: String
        }
        try await supabase
            .rpc("remove_saved_recipe", params: RemoveParams(
                user_id: userID.uuidString,
                recipe_id: recipeID.uuidString
            ))
            .execute()
    }
}

// MARK: - Admin Service

final class SupabaseAdminService: AdminServiceProtocol {

    func fetchMasterIngredients() async throws -> [MasterIngredient] {
        struct IngredientDTO: Decodable {
            let id: UUID
            let name: String
            let category: String
            let allergenTags: [String]
            let isActive: Bool
            enum CodingKeys: String, CodingKey {
                case id, name, category
                case allergenTags = "allergen_tags"
                case isActive     = "is_active"
            }
        }
        let response: [IngredientDTO] = try await supabase
            .from("master_ingredients")
            .select()
            .execute()
            .value
        return response.map {
            MasterIngredient(id: $0.id, name: $0.name, category: $0.category,
                             allergenTags: $0.allergenTags, isActive: $0.isActive)
        }
    }

    func fetchMasterDietTags() async throws -> [MasterDietTag] {
        struct TagDTO: Decodable {
            let id: UUID
            let name: String
            let iconName: String
            let isActive: Bool
            enum CodingKeys: String, CodingKey {
                case id, name
                case iconName = "icon_name"
                case isActive = "is_active"
            }
        }
        let response: [TagDTO] = try await supabase
            .from("master_diet_tags")
            .select()
            .execute()
            .value
        return response.map {
            MasterDietTag(id: $0.id, name: $0.name, iconName: $0.iconName, isActive: $0.isActive)
        }
    }

    // Only fetches rows still awaiting a moderation decision.
    func fetchPendingContent() async throws -> [PendingContent] {
        struct PendingDTO: Decodable {
            let id: UUID
            let recipeId: UUID
            let submittedBy: UUID
            let status: String
            let moderatorNote: String
            enum CodingKeys: String, CodingKey {
                case id, status
                case recipeId      = "recipe_id"
                case submittedBy   = "submitted_by"
                case moderatorNote = "moderator_note"
            }
        }
        let response: [PendingDTO] = try await supabase
            .from("pending_content")
            .select()
            .eq("status", value: "pending")
            .execute()
            .value
        return response.map {
            PendingContent(id: $0.id, recipeID: $0.recipeId,
                           submittedByUserID: $0.submittedBy, status: $0.status)
        }
    }

    func createIngredient(_ ingredient: MasterIngredient) async throws {
        struct IngredientInsert: Encodable {
            let name: String
            let category: String
        }
        try await supabase
            .from("master_ingredients")
            .insert(IngredientInsert(name: ingredient.name, category: ingredient.category))
            .execute()
    }

    func updateIngredient(_ ingredient: MasterIngredient) async throws {
        struct IngredientUpdate: Encodable {
            let name: String
            let is_active: Bool
        }
        try await supabase
            .from("master_ingredients")
            .update(IngredientUpdate(name: ingredient.name, is_active: ingredient.isActive))
            .eq("id", value: ingredient.id)
            .execute()
    }

    func createDietTag(_ tag: MasterDietTag) async throws {
        struct TagInsert: Encodable {
            let name: String
            let icon_name: String
        }
        try await supabase
            .from("master_diet_tags")
            .insert(TagInsert(name: tag.name, icon_name: tag.iconName))
            .execute()
    }

    func updateDietTag(_ tag: MasterDietTag) async throws {
        struct TagUpdate: Encodable {
            let name: String
            let is_active: Bool
        }
        try await supabase
            .from("master_diet_tags")
            .update(TagUpdate(name: tag.name, is_active: tag.isActive))
            .eq("id", value: tag.id)
            .execute()
    }

    // Updates a pending submission to "approved" or "rejected" and optionally
    // attaches a moderator note explaining the decision.
    func updateContentStatus(_ id: UUID, status: String, note: String) async throws {
        struct StatusUpdate: Encodable {
            let status: String
            let moderator_note: String
        }
        try await supabase
            .from("pending_content")
            .update(StatusUpdate(status: status, moderator_note: note))
            .eq("id", value: id)
            .execute()
    }
}
