import Foundation
import Supabase

// MARK: - Protocol

protocol CreatorUploadServiceProtocol {
    func uploadVideo(_ videoData: Data, filename: String) async throws -> String
    func uploadThumbnail(_ thumbnailData: Data, filename: String) async throws -> String
    func submitRecipe(_ draft: RecipeDraft, videoURL: String, thumbnailURL: String) async throws -> Recipe
    func fetchMySubmissions() async throws -> [CreatorSubmission]
}

// MARK: - Draft Model

struct RecipeDraft {
    var title: String = ""
    var description: String = ""
    var dietTags: [String] = []
    var allergenTags: [String] = []
    var ingredients: [String] = []
    var steps: [RecipeStep] = []
}

// MARK: - Submission Model

struct CreatorSubmission: Identifiable {
    let id: UUID
    let recipe: Recipe
    let status: String
    let moderatorNote: String
    let submittedAt: Date
}

// MARK: - Real Supabase Implementation

final class SupabaseCreatorUploadService: CreatorUploadServiceProtocol {

    private let videoBucket     = "recipe-videos"
    private let thumbnailBucket = "recipe-thumbnails"

    private func currentUserID() async throws -> UUID {
        guard let session = try? await supabase.auth.session else {
            throw CreatorUploadError.notAuthenticated
        }
        return session.user.id
    }

    func uploadVideo(_ videoData: Data, filename: String) async throws -> String {
        _ = try await currentUserID()

        let path = "\(UUID().uuidString)/\(filename)"
        _ = try await supabase.storage
            .from(videoBucket)
            .upload(path, data: videoData, options: FileOptions(contentType: "video/mp4"))
        let publicURL = try supabase.storage
            .from(videoBucket)
            .getPublicURL(path: path)
        return publicURL.absoluteString
    }

    func uploadThumbnail(_ thumbnailData: Data, filename: String) async throws -> String {
        _ = try await currentUserID()

        let path = "\(UUID().uuidString)/\(filename)"
        _ = try await supabase.storage
            .from(thumbnailBucket)
            .upload(path, data: thumbnailData, options: FileOptions(contentType: "image/jpeg"))
        let publicURL = try supabase.storage
            .from(thumbnailBucket)
            .getPublicURL(path: path)
        return publicURL.absoluteString
    }

    func submitRecipe(_ draft: RecipeDraft, videoURL: String, thumbnailURL: String) async throws -> Recipe {
        let userID   = try await currentUserID()
        let session  = try await supabase.auth.session
        let username = session.user.email?.components(separatedBy: "@").first ?? "creator"

        let stepsData = (try? JSONEncoder().encode(draft.steps)) ?? Data()

        struct RecipeInsert: Encodable {
            let title: String
            let creator_id: String
            let creator_username: String
            let video_url: String
            let thumbnail_url: String
            let recipe_description: String
            let diet_tags: [String]
            let allergen_tags: [String]
            let ingredients: [String]
            let steps: [RecipeStep]
            let is_approved: Bool
        }

        let insert = RecipeInsert(
            title: draft.title,
            creator_id: userID.uuidString,
            creator_username: username,
            video_url: videoURL,
            thumbnail_url: thumbnailURL,
            recipe_description: draft.description,
            diet_tags: draft.dietTags,
            allergen_tags: draft.allergenTags,
            ingredients: draft.ingredients,
            steps: draft.steps,
            is_approved: true
        )

        struct InsertedID: Decodable { let id: UUID }
        let recipeID: UUID
        
        do {
            let inserted: [InsertedID] = try await supabase
                .from("recipes")
                .insert(insert)
                .select("id")
                .execute()
                .value

            guard let id = inserted.first?.id else {
                throw URLError(.badServerResponse)
            }
            recipeID = id
        } catch {
            print("[ERROR CATCHER - TABEL RECIPES]: \(error)")
            throw error
        }

        return Recipe(
            id: recipeID,
            title: draft.title,
            creatorID: userID,
            creatorUsername: username,
            videoURL: videoURL,
            thumbnailURL: thumbnailURL,
            recipeDescription: draft.description,
            dietTags: draft.dietTags,
            allergenTags: draft.allergenTags,
            ingredients: draft.ingredients,
            steps: stepsData,
            createdAt: Date()
        )
    }

    func fetchMySubmissions() async throws -> [CreatorSubmission] {
        let userID = try await currentUserID()

        // Langsung menarik data dari tabel public.recipes yang mutlak
        let response: [RecipeDTO] = try await supabase
            .from("recipes")
            .select()
            .eq("creator_id", value: userID.uuidString)
            .order("created_at", ascending: false)
            .execute()
            .value

        return response.map { dto in
            let recipe = dto.toRecipe() // Konversi DTO menjadi Model Recipe
            return CreatorSubmission(
                id: recipe.id,
                recipe: recipe,
                status: "approved", // Karena memotong antrean, mutlak diset approved
                moderatorNote: "",
                submittedAt: recipe.createdAt
            )
        }
    }
}

// MARK: - Errors

enum CreatorUploadError: LocalizedError {
    case notAuthenticated

    var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            return "You must be signed in to upload a recipe. Please sign in and try again."
        }
    }
}
