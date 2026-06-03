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

    // FIX: "auth session missing"
    // Always resolve the current user ID from the live Supabase session.
    // Previously this was called inside submitRecipe which could run before
    // the authStateChanges stream had fired .signedIn.
    // Guard early and throw a clear error if called unauthenticated.
    private func currentUserID() async throws -> UUID {
        guard let session = try? await supabase.auth.session else {
            throw CreatorUploadError.notAuthenticated
        }
        return session.user.id
    }

    func uploadVideo(_ videoData: Data, filename: String) async throws -> String {
        // Verify session exists before touching storage
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

        let stepsData   = (try? JSONEncoder().encode(draft.steps)) ?? Data()
        let stepsBase64 = stepsData.base64EncodedString()

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
            let steps: String
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
            steps: stepsBase64,
            is_approved: false
        )

        struct InsertedID: Decodable { let id: UUID }
        let inserted: [InsertedID] = try await supabase
            .from("recipes")
            .insert(insert)
            .select("id")
            .execute()
            .value

        guard let recipeID = inserted.first?.id else {
            throw URLError(.badServerResponse)
        }

        struct PendingInsert: Encodable {
            let recipe_id: String
            let submitted_by: String
            let status: String
        }
        try await supabase
            .from("pending_content")
            .insert(PendingInsert(
                recipe_id: recipeID.uuidString,
                submitted_by: userID.uuidString,
                status: "pending"
            ))
            .execute()

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

        struct SubmissionDTO: Decodable {
            let id: UUID
            let status: String
            let moderator_note: String
            let created_at: Date
            let recipe: RecipeDTO

            struct RecipeDTO: Decodable {
                let id: UUID
                let title: String
                let creator_id: UUID
                let creator_username: String
                let video_url: String
                let thumbnail_url: String
                let recipe_description: String
                let diet_tags: [String]
                let allergen_tags: [String]
                let ingredients: [String]
                let created_at: Date
            }
        }

        let response: [SubmissionDTO] = try await supabase
            .from("pending_content")
            .select("id, status, moderator_note, created_at, recipe:recipes(*)")
            .eq("submitted_by", value: userID.uuidString)
            .order("created_at", ascending: false)
            .execute()
            .value

        return response.map { dto in
            let r = dto.recipe
            let recipe = Recipe(
                id: r.id,
                title: r.title,
                creatorID: r.creator_id,
                creatorUsername: r.creator_username,
                videoURL: r.video_url,
                thumbnailURL: r.thumbnail_url,
                recipeDescription: r.recipe_description,
                dietTags: r.diet_tags,
                allergenTags: r.allergen_tags,
                ingredients: r.ingredients,
                createdAt: r.created_at
            )
            return CreatorSubmission(
                id: dto.id,
                recipe: recipe,
                status: dto.status,
                moderatorNote: dto.moderator_note,
                submittedAt: dto.created_at
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
