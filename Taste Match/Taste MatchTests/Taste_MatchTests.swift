import XCTest
@testable import Taste_Match

final class DietTagTests: XCTestCase {
    func test_dietTag_rawValues_areHumanReadable() {
        XCTAssertEqual(DietTag.halal.rawValue, "Halal")
        XCTAssertEqual(DietTag.vegan.rawValue, "Vegan")
        XCTAssertEqual(DietTag.vegetarian.rawValue, "Vegetarian")
        XCTAssertEqual(DietTag.glutenFree.rawValue, "Gluten-Free")
        XCTAssertEqual(DietTag.dairyFree.rawValue, "Dairy-Free")
    }
    func test_dietTag_id_equalsRawValue() {
        for tag in DietTag.allCases {
            XCTAssertEqual(tag.id, tag.rawValue)
        }
    }
    func test_allergenTag_rawValues_areCorrectlyCased() {
        XCTAssertEqual(AllergenTag.nuts.rawValue, "Nuts")
        XCTAssertEqual(AllergenTag.gluten.rawValue, "Gluten")
        XCTAssertEqual(AllergenTag.dairy.rawValue, "Dairy")
        XCTAssertEqual(AllergenTag.shellfish.rawValue, "Shellfish")
        XCTAssertEqual(AllergenTag.soy.rawValue, "Soy")
    }
    func test_dietTag_caseIterable_containsAllCases() {
        XCTAssertEqual(DietTag.allCases.count, 5)
    }
}

final class RecipeStepTests: XCTestCase {
    func test_recipeStep_encodesAndDecodesCorrectly() throws {
        let step = RecipeStep(stepNumber: 1, instruction: "Chop the garlic finely", durationMinutes: 5)
        let data = try JSONEncoder().encode(step)
        let decoded = try JSONDecoder().decode(RecipeStep.self, from: data)
        XCTAssertEqual(decoded.stepNumber, step.stepNumber)
        XCTAssertEqual(decoded.instruction, step.instruction)
        XCTAssertEqual(decoded.durationMinutes, step.durationMinutes)
    }
    func test_recipeStep_nilDuration_roundTripsCorrectly() throws {
        let step = RecipeStep(stepNumber: 2, instruction: "Mix everything together", durationMinutes: nil)
        let data = try JSONEncoder().encode(step)
        let decoded = try JSONDecoder().decode(RecipeStep.self, from: data)
        XCTAssertNil(decoded.durationMinutes)
    }
    func test_recipeSteps_array_roundTripsCorrectly() throws {
        let steps = [
            RecipeStep(stepNumber: 1, instruction: "Boil water", durationMinutes: 10),
            RecipeStep(stepNumber: 2, instruction: "Add pasta", durationMinutes: 8),
        ]
        let data = try JSONEncoder().encode(steps)
        let decoded = try JSONDecoder().decode([RecipeStep].self, from: data)
        XCTAssertEqual(decoded.count, 2)
        XCTAssertEqual(decoded[0].instruction, "Boil water")
        XCTAssertEqual(decoded[1].stepNumber, 2)
    }
}

final class RecipeDecodedStepsTests: XCTestCase {
    private let creatorID = UUID()
    func test_decodedSteps_withValidData_returnsSteps() throws {
        let steps = [RecipeStep(stepNumber: 1, instruction: "Preheat oven", durationMinutes: nil)]
        let stepsData = try JSONEncoder().encode(steps)
        let recipe = Recipe(title: "Test", creatorID: creatorID, creatorUsername: "chef", videoURL: "", thumbnailURL: "", recipeDescription: "", steps: stepsData)
        XCTAssertEqual(recipe.decodedSteps.count, 1)
        XCTAssertEqual(recipe.decodedSteps.first?.instruction, "Preheat oven")
    }
    func test_decodedSteps_withCorruptData_returnsEmptyArray() {
        let corruptData = Data("not json".utf8)
        let recipe = Recipe(title: "Bad", creatorID: creatorID, creatorUsername: "chef", videoURL: "", thumbnailURL: "", recipeDescription: "", steps: corruptData)
        XCTAssertTrue(recipe.decodedSteps.isEmpty)
    }
    func test_decodedSteps_withDefaultEmptyData_returnsEmptyArray() {
        let recipe = Recipe(title: "Empty", creatorID: creatorID, creatorUsername: "chef", videoURL: "", thumbnailURL: "", recipeDescription: "")
        XCTAssertTrue(recipe.decodedSteps.isEmpty)
    }
}

final class UserProfileTests: XCTestCase {
    func test_isAdmin_withAdminRole_returnsTrue() {
        let admin = UserProfile(id: UUID(), email: "admin@test.com", username: "admin", role: UserRole.admin.rawValue)
        XCTAssertTrue(admin.isAdmin)
    }
    func test_isAdmin_withUserRole_returnsFalse() {
        let user = UserProfile(id: UUID(), email: "user@test.com", username: "user", role: UserRole.user.rawValue)
        XCTAssertFalse(user.isAdmin)
    }
    func test_isAdmin_withCreatorRole_returnsFalse() {
        let creator = UserProfile(id: UUID(), email: "c@test.com", username: "c", role: UserRole.creator.rawValue)
        XCTAssertFalse(creator.isAdmin)
    }
    func test_isAdmin_withMixedCaseAdminRole_returnsTrue() {
        let admin = UserProfile(id: UUID(), email: "a@test.com", username: "a", role: "ADMIN")
        XCTAssertTrue(admin.isAdmin)
    }
    func test_userProfile_defaultValues_areCorrect() {
        let user = UserProfile(id: UUID(), email: "x@test.com", username: "x")
        XCTAssertEqual(user.role, UserRole.user.rawValue)
        XCTAssertTrue(user.activeDietTags.isEmpty)
        XCTAssertTrue(user.blacklistedIngredients.isEmpty)
        XCTAssertTrue(user.savedPlaylist.isEmpty)
        XCTAssertEqual(user.avatarURL, "")
    }
    func test_userRole_rawValues_matchDatabaseStrings() {
        XCTAssertEqual(UserRole.user.rawValue, "user")
        XCTAssertEqual(UserRole.creator.rawValue, "creator")
        XCTAssertEqual(UserRole.admin.rawValue, "admin")
    }
}

final class MockCreatorUploadService: CreatorUploadServiceProtocol {
    func uploadVideo(_ videoData: Data, filename: String) async throws -> String { "https://video.url" }
    func uploadThumbnail(_ thumbnailData: Data, filename: String) async throws -> String { "https://thumb.url" }
    func submitRecipe(_ draft: RecipeDraft, videoURL: String, thumbnailURL: String) async throws -> Recipe {
        Recipe(title: draft.title, creatorID: UUID(), creatorUsername: "mock", videoURL: videoURL, thumbnailURL: thumbnailURL, recipeDescription: draft.description)
    }
    func fetchMySubmissions() async throws -> [CreatorSubmission] { [] }
}


final class UploadPhaseTests: XCTestCase {
    func test_uploadPhase_idle_equalsIdle() {
        XCTAssertEqual(UploadPhase.idle, UploadPhase.idle)
    }
    func test_uploadPhase_failed_withSameMessage_isEqual() {
        XCTAssertEqual(UploadPhase.failed("err"), UploadPhase.failed("err"))
    }
    func test_uploadPhase_failed_withDifferentMessages_isNotEqual() {
        XCTAssertNotEqual(UploadPhase.failed("err1"), UploadPhase.failed("err2"))
    }
    func test_uploadPhase_done_withSameRecipeID_isEqual() {
        let id = UUID()
        let recipe = Recipe(title: "R", creatorID: id, creatorUsername: "u", videoURL: "", thumbnailURL: "", recipeDescription: "")
        XCTAssertEqual(UploadPhase.done(recipe), UploadPhase.done(recipe))
    }
}
