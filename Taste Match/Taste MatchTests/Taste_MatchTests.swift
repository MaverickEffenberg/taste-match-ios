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

final class MockProfileService: ProfileServiceProtocol {
    func fetchProfile() async throws -> UserProfile? { nil }
    func updateProfile(dietTags: [String], blacklist: [String]) async throws {}
    func saveRecipe(_ recipeID: UUID) async throws {}
    func unsaveRecipe(_ recipeID: UUID) async throws {}
    func fetchSavedRecipesDetails(for ids: [UUID]) async throws -> [Recipe] { [] }
}

final class MockRecipeService: RecipeServiceProtocol {
    var recipesToReturn: [Recipe] = []
    func fetchApprovedRecipes() async throws -> [Recipe] { recipesToReturn }
    func searchByIngredients(_ ingredients: [String]) async throws -> [Recipe] { recipesToReturn }
    func fetchIngredientSuggestions(prefix: String) async throws -> [String] { [] }
    func fetchMediaPublicURL(bucket: String, path: String) -> URL { URL(string: "https://example.com")! }
}

@MainActor
final class FeedViewModelFilterTests: XCTestCase {
    private let creatorID = UUID()
    private func makeRecipe(title: String, ingredients: [String], dietTags: [String]) -> Recipe {
        Recipe(title: title, creatorID: creatorID, creatorUsername: "chef", videoURL: "", thumbnailURL: "", recipeDescription: "", dietTags: dietTags, ingredients: ingredients)
    }
    private func makeProfileVM(dietTags: [String] = [], blacklist: [String] = []) -> ProfileViewModel {
        let vm = ProfileViewModel(profileService: MockProfileService(), localStore: LocalDataService.shared)
        vm.activeDietTags = dietTags
        vm.blacklistedIngredients = blacklist
        return vm
    }
    private func makeFeedVM(profileVM: ProfileViewModel) -> FeedViewModel {
        FeedViewModel(recipeService: MockRecipeService(), profileViewModel: profileVM)
    }
    func test_applyProfileFilter_noFilters_returnsAll() {
        let recipes = [makeRecipe(title: "A", ingredients: ["chicken"], dietTags: ["Halal"]), makeRecipe(title: "B", ingredients: ["tofu"], dietTags: ["Vegan"])]
        let vm = makeFeedVM(profileVM: makeProfileVM())
        XCTAssertEqual(vm.applyProfileFilter(to: recipes).count, 2)
    }
    func test_applyProfileFilter_blacklistedIngredient_isExcluded() {
        let safe = makeRecipe(title: "Safe", ingredients: ["chicken"], dietTags: [])
        let unsafe = makeRecipe(title: "Unsafe", ingredients: ["peanut butter"], dietTags: [])
        let vm = makeFeedVM(profileVM: makeProfileVM(blacklist: ["peanut butter"]))
        let result = vm.applyProfileFilter(to: [safe, unsafe])
        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result.first?.title, "Safe")
    }
    func test_applyProfileFilter_blacklist_isCaseInsensitive() {
        let recipe = makeRecipe(title: "Risky", ingredients: ["Peanut Butter"], dietTags: [])
        let vm = makeFeedVM(profileVM: makeProfileVM(blacklist: ["peanut butter"]))
        XCTAssertTrue(vm.applyProfileFilter(to: [recipe]).isEmpty)
    }
    func test_applyProfileFilter_missingRequiredDietTag_isExcluded() {
        let vegan = makeRecipe(title: "Vegan", ingredients: [], dietTags: ["Vegan"])
        let halal = makeRecipe(title: "Halal", ingredients: [], dietTags: ["Halal"])
        let vm = makeFeedVM(profileVM: makeProfileVM(dietTags: ["Vegan"]))
        let result = vm.applyProfileFilter(to: [vegan, halal])
        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result.first?.title, "Vegan")
    }
    func test_applyProfileFilter_recipeHasAllRequiredTags_isIncluded() {
        let recipe = makeRecipe(title: "Combo", ingredients: [], dietTags: ["Vegan", "Gluten-Free"])
        let vm = makeFeedVM(profileVM: makeProfileVM(dietTags: ["Vegan", "Gluten-Free"]))
        XCTAssertEqual(vm.applyProfileFilter(to: [recipe]).count, 1)
    }
    func test_applyProfileFilter_combinedFilters_worksCorrectly() {
        let good = makeRecipe(title: "Good", ingredients: ["spinach"], dietTags: ["Vegan"])
        let badA = makeRecipe(title: "BadA", ingredients: ["peanut butter"], dietTags: ["Vegan"])
        let badB = makeRecipe(title: "BadB", ingredients: ["spinach"], dietTags: ["Halal"])
        let vm = makeFeedVM(profileVM: makeProfileVM(dietTags: ["Vegan"], blacklist: ["peanut butter"]))
        let result = vm.applyProfileFilter(to: [good, badA, badB])
        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result.first?.title, "Good")
    }
}

@MainActor
final class SearchViewModelTests: XCTestCase {
    private func makeSearchVM() -> SearchViewModel {
        SearchViewModel(recipeService: MockRecipeService(), profileViewModel: ProfileViewModel(profileService: MockProfileService(), localStore: LocalDataService.shared))
    }
    func test_initialState_isEmpty() {
        let vm = makeSearchVM()
        XCTAssertTrue(vm.selectedIngredients.isEmpty)
        XCTAssertTrue(vm.searchResults.isEmpty)
        XCTAssertEqual(vm.searchQuery, "")
    }
    func test_addIngredient_appendsToBasket() {
        let vm = makeSearchVM()
        vm.addIngredient("garlic")
        XCTAssertEqual(vm.selectedIngredients, ["garlic"])
        XCTAssertEqual(vm.searchQuery, "")
    }
    func test_addIngredient_duplicate_isIgnored() {
        let vm = makeSearchVM()
        vm.addIngredient("garlic")
        vm.addIngredient("garlic")
        XCTAssertEqual(vm.selectedIngredients.count, 1)
    }
    func test_addIngredient_whitespaceOnly_isIgnored() {
        let vm = makeSearchVM()
        vm.addIngredient("   ")
        XCTAssertTrue(vm.selectedIngredients.isEmpty)
    }
    func test_addIngredient_withWhitespace_isTrimmed() {
        let vm = makeSearchVM()
        vm.addIngredient("  garlic  ")
        XCTAssertEqual(vm.selectedIngredients.first, "garlic")
    }
    func test_removeIngredient_removesFromBasket() {
        let vm = makeSearchVM()
        vm.addIngredient("garlic")
        vm.addIngredient("onion")
        vm.removeIngredient("garlic")
        XCTAssertEqual(vm.selectedIngredients, ["onion"])
    }
    func test_removeIngredient_notInBasket_doesNothing() {
        let vm = makeSearchVM()
        vm.addIngredient("garlic")
        vm.removeIngredient("onion")
        XCTAssertEqual(vm.selectedIngredients, ["garlic"])
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

@MainActor
final class CreatorViewModelTests: XCTestCase {
    private func makeVM() -> CreatorViewModel {
        CreatorViewModel(uploadService: MockCreatorUploadService())
    }
    func test_canSubmit_withEmptyDraft_returnsFalse() {
        XCTAssertFalse(makeVM().canSubmit)
    }
    func test_canSubmit_withAllFieldsFilled_returnsTrue() {
        let vm = makeVM()
        vm.videoData = Data([0x00])
        vm.thumbnailData = Data([0xFF])
        vm.draft.title = "Vegan Bowl"
        vm.draft.description = "A tasty bowl"
        vm.draft.ingredients = ["tofu"]
        vm.draft.steps = [RecipeStep(stepNumber: 1, instruction: "Mix", durationMinutes: nil)]
        XCTAssertTrue(vm.canSubmit)
    }
    func test_canSubmit_missingVideo_returnsFalse() {
        let vm = makeVM()
        vm.thumbnailData = Data([0xFF])
        vm.draft.title = "Title"
        vm.draft.description = "Desc"
        vm.draft.ingredients = ["ingredient"]
        vm.draft.steps = [RecipeStep(stepNumber: 1, instruction: "Step", durationMinutes: nil)]
        XCTAssertFalse(vm.canSubmit)
    }
    func test_canSubmit_whitespaceOnlyTitle_returnsFalse() {
        let vm = makeVM()
        vm.videoData = Data([0x00])
        vm.thumbnailData = Data([0xFF])
        vm.draft.title = "   "
        vm.draft.description = "Desc"
        vm.draft.ingredients = ["ingredient"]
        vm.draft.steps = [RecipeStep(stepNumber: 1, instruction: "Step", durationMinutes: nil)]
        XCTAssertFalse(vm.canSubmit)
    }
    func test_canSubmit_emptyIngredients_returnsFalse() {
        let vm = makeVM()
        vm.videoData = Data([0x00])
        vm.thumbnailData = Data([0xFF])
        vm.draft.title = "Title"
        vm.draft.description = "Desc"
        vm.draft.ingredients = []
        vm.draft.steps = [RecipeStep(stepNumber: 1, instruction: "Step", durationMinutes: nil)]
        XCTAssertFalse(vm.canSubmit)
    }
    func test_resetForm_clearsAllDraftAndMediaState() {
        let vm = makeVM()
        vm.videoData = Data([0x00])
        vm.thumbnailData = Data([0xFF])
        vm.draft.title = "My Recipe"
        vm.draft.ingredients = ["garlic"]
        vm.resetForm()
        XCTAssertNil(vm.videoData)
        XCTAssertNil(vm.thumbnailData)
        XCTAssertEqual(vm.draft.title, "")
        XCTAssertTrue(vm.draft.ingredients.isEmpty)
    }
    func test_resetUploadState_resetsPhaseAndError() {
        let vm = makeVM()
        vm.uploadPhase = .failed("error")
        vm.errorMessage = "error"
        vm.uploadProgress = 0.75
        vm.resetUploadState()
        XCTAssertEqual(vm.uploadPhase, .idle)
        XCTAssertNil(vm.errorMessage)
        XCTAssertEqual(vm.uploadProgress, 0.0, accuracy: 0.001)
    }
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
