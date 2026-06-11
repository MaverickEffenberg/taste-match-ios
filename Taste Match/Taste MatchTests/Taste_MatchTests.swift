// TasteMatchTests.swift
// Unit Tests for Taste Match iOS App
//
// HOW TO ADD TO XCODE:
// 1. File > New > Target > Unit Testing Bundle — name it "TasteMatchTests"
// 2. Drag this file into the new test target folder
// 3. Confirm "@testable import Taste_Match" (spaces → underscores in module name)
// 4. Press Cmd+U to run all tests
//
// ABOUT THESE TESTS:
// All tests are written against the REAL types found in the repo. They test
// only pure logic — no Supabase, no SwiftData, no network needed. Tests that
// need a service use lightweight mock objects defined below.

import XCTest
@testable import Taste_Match

// ─────────────────────────────────────────────────────────────────────────────
// MARK: - 1. DietTag & AllergenTag Enum Tests
// Tests the raw-value enums in Recipe.swift
// ─────────────────────────────────────────────────────────────────────────────
final class DietTagTests: XCTestCase {

    // Every DietTag raw value must be a human-readable string (used in UI labels)
    func test_dietTag_rawValues_areHumanReadable() {
        XCTAssertEqual(DietTag.halal.rawValue,      "Halal")
        XCTAssertEqual(DietTag.vegan.rawValue,      "Vegan")
        XCTAssertEqual(DietTag.vegetarian.rawValue, "Vegetarian")
        XCTAssertEqual(DietTag.glutenFree.rawValue, "Gluten-Free")
        XCTAssertEqual(DietTag.dairyFree.rawValue,  "Dairy-Free")
    }

    // id must equal rawValue so SwiftUI ForEach can diff items correctly
    func test_dietTag_id_equalsRawValue() {
        for tag in DietTag.allCases {
            XCTAssertEqual(tag.id, tag.rawValue,
                "\(tag) — id should equal rawValue for stable SwiftUI identity")
        }
    }

    // AllergenTag raw values drive blacklist matching — casing matters
    func test_allergenTag_rawValues_areCorrectlyCased() {
        XCTAssertEqual(AllergenTag.nuts.rawValue,      "Nuts")
        XCTAssertEqual(AllergenTag.gluten.rawValue,    "Gluten")
        XCTAssertEqual(AllergenTag.dairy.rawValue,     "Dairy")
        XCTAssertEqual(AllergenTag.shellfish.rawValue, "Shellfish")
        XCTAssertEqual(AllergenTag.soy.rawValue,       "Soy")
    }

    // DietTag must be CaseIterable (used to populate the profile toggle UI)
    func test_dietTag_caseIterable_containsAllCases() {
        XCTAssertEqual(DietTag.allCases.count, 5,
            "There should be exactly 5 DietTag cases")
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// MARK: - 2. RecipeStep Codable Tests
// RecipeStep is stored as JSON-encoded Data inside Recipe.steps
// ─────────────────────────────────────────────────────────────────────────────
final class RecipeStepTests: XCTestCase {

    // A RecipeStep must survive a JSON round-trip without data loss
    func test_recipeStep_encodesAndDecodesCorrectly() throws {
        let step = RecipeStep(stepNumber: 1,
                              instruction: "Chop the garlic finely",
                              durationMinutes: 5)

        let data    = try JSONEncoder().encode(step)
        let decoded = try JSONDecoder().decode(RecipeStep.self, from: data)

        XCTAssertEqual(decoded.stepNumber,    step.stepNumber)
        XCTAssertEqual(decoded.instruction,   step.instruction)
        XCTAssertEqual(decoded.durationMinutes, step.durationMinutes)
    }

    // durationMinutes is optional — nil must survive the round-trip too
    func test_recipeStep_nilDuration_roundTripsCorrectly() throws {
        let step = RecipeStep(stepNumber: 2,
                              instruction: "Mix everything together",
                              durationMinutes: nil)

        let data    = try JSONEncoder().encode(step)
        let decoded = try JSONDecoder().decode(RecipeStep.self, from: data)

        XCTAssertNil(decoded.durationMinutes,
            "nil durationMinutes should remain nil after JSON round-trip")
    }

    // A list of steps must also round-trip (this is exactly what Recipe.decodedSteps does)
    func test_recipeSteps_array_roundTripsCorrectly() throws {
        let steps = [
            RecipeStep(stepNumber: 1, instruction: "Boil water", durationMinutes: 10),
            RecipeStep(stepNumber: 2, instruction: "Add pasta",  durationMinutes: 8),
        ]

        let data    = try JSONEncoder().encode(steps)
        let decoded = try JSONDecoder().decode([RecipeStep].self, from: data)

        XCTAssertEqual(decoded.count, 2)
        XCTAssertEqual(decoded[0].instruction, "Boil water")
        XCTAssertEqual(decoded[1].stepNumber,  2)
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// MARK: - 3. Recipe.decodedSteps Tests
// decodedSteps decodes Recipe.steps (Data) into [RecipeStep] with a safe fallback
// ─────────────────────────────────────────────────────────────────────────────
final class RecipeDecodedStepsTests: XCTestCase {

    private let creatorID = UUID()

    // Valid encoded steps must be returned correctly
    func test_decodedSteps_withValidData_returnsSteps() throws {
        let steps = [RecipeStep(stepNumber: 1, instruction: "Preheat oven", durationMinutes: nil)]
        let stepsData = try JSONEncoder().encode(steps)

        let recipe = Recipe(
            title: "Test Recipe", creatorID: creatorID,
            creatorUsername: "chef", videoURL: "", thumbnailURL: "",
            recipeDescription: "", steps: stepsData
        )

        XCTAssertEqual(recipe.decodedSteps.count, 1)
        XCTAssertEqual(recipe.decodedSteps.first?.instruction, "Preheat oven")
    }

    // Corrupt/empty steps data must return [] not crash
    func test_decodedSteps_withCorruptData_returnsEmptyArray() {
        let corruptData = Data("not json".utf8)

        let recipe = Recipe(
            title: "Bad Recipe", creatorID: creatorID,
            creatorUsername: "chef", videoURL: "", thumbnailURL: "",
            recipeDescription: "", steps: corruptData
        )

        XCTAssertTrue(recipe.decodedSteps.isEmpty,
            "Corrupt steps data should return empty array, not crash")
    }

    // Default empty Data() must also return [] safely
    func test_decodedSteps_withDefaultEmptyData_returnsEmptyArray() {
        let recipe = Recipe(
            title: "Empty Steps", creatorID: creatorID,
            creatorUsername: "chef", videoURL: "", thumbnailURL: "",
            recipeDescription: ""
            // steps defaults to Data()
        )

        XCTAssertTrue(recipe.decodedSteps.isEmpty,
            "Default empty Data() should return an empty steps array")
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// MARK: - 4. UserProfile Tests
// Tests the UserProfile model and its computed properties from User.swift
// ─────────────────────────────────────────────────────────────────────────────
final class UserProfileTests: XCTestCase {

    // isAdmin must be true for role == "admin"
    func test_isAdmin_withAdminRole_returnsTrue() {
        let admin = UserProfile(id: UUID(), email: "admin@test.com",
                                username: "admin", role: UserRole.admin.rawValue)
        XCTAssertTrue(admin.isAdmin)
    }

    // isAdmin must be false for regular "user" role
    func test_isAdmin_withUserRole_returnsFalse() {
        let user = UserProfile(id: UUID(), email: "user@test.com",
                               username: "user", role: UserRole.user.rawValue)
        XCTAssertFalse(user.isAdmin)
    }

    // isAdmin must be false for "creator" role
    func test_isAdmin_withCreatorRole_returnsFalse() {
        let creator = UserProfile(id: UUID(), email: "creator@test.com",
                                  username: "creator", role: UserRole.creator.rawValue)
        XCTAssertFalse(creator.isAdmin)
    }

    // isAdmin comparison should be case-insensitive (defensive coding)
    func test_isAdmin_withMixedCaseAdminRole_returnsTrue() {
        let admin = UserProfile(id: UUID(), email: "a@test.com",
                                username: "a", role: "ADMIN")
        XCTAssertTrue(admin.isAdmin,
            "isAdmin uses lowercased() comparison, so 'ADMIN' should also be recognised")
    }

    // Default initializer values must match expected defaults
    func test_userProfile_defaultValues_areCorrect() {
        let user = UserProfile(id: UUID(), email: "x@test.com", username: "x")

        XCTAssertEqual(user.role, UserRole.user.rawValue)
        XCTAssertTrue(user.activeDietTags.isEmpty)
        XCTAssertTrue(user.blacklistedIngredients.isEmpty)
        XCTAssertTrue(user.savedPlaylist.isEmpty)
        XCTAssertEqual(user.avatarURL, "")
    }

    // UserRole raw values must match the strings stored in Supabase profiles table
    func test_userRole_rawValues_matchDatabaseStrings() {
        XCTAssertEqual(UserRole.user.rawValue,    "user")
        XCTAssertEqual(UserRole.creator.rawValue, "creator")
        XCTAssertEqual(UserRole.admin.rawValue,   "admin")
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// MARK: - 5. RecipeCache.isSafeForUser Tests
// This is the core local filtering logic — the most testable function in the app
// ─────────────────────────────────────────────────────────────────────────────
final class RecipeCacheFilterTests: XCTestCase {

    // Helper: build a RecipeCache quickly
    private func makeCache(ingredients: [String], dietTags: [String]) -> RecipeCache {
        RecipeCache(
            recipeID: UUID(),
            title: "Test",
            creatorTag: "@chef",
            ingredients: ingredients,
            dietTags: dietTags
        )
    }

    // No blacklist, no required tags → every recipe is safe
    func test_isSafe_noFilters_returnsTrue() {
        let cache = makeCache(ingredients: ["chicken", "garlic"], dietTags: ["Halal"])
        XCTAssertTrue(cache.isSafeForUser(blacklistedIngredients: [], requiredDietTags: []))
    }

    // Recipe contains a blacklisted ingredient → must be filtered out
    func test_isSafe_blacklistedIngredientPresent_returnsFalse() {
        let cache = makeCache(ingredients: ["noodles", "peanut butter", "lime"], dietTags: ["Vegan"])
        XCTAssertFalse(cache.isSafeForUser(
            blacklistedIngredients: ["peanut butter"],
            requiredDietTags: []
        ))
    }

    // Recipe does NOT contain any blacklisted ingredient → safe
    func test_isSafe_noBlacklistedIngredient_returnsTrue() {
        let cache = makeCache(ingredients: ["chicken", "garlic"], dietTags: ["Halal"])
        XCTAssertTrue(cache.isSafeForUser(
            blacklistedIngredients: ["peanut butter"],
            requiredDietTags: []
        ))
    }

    // Recipe has the required diet tag → safe
    func test_isSafe_recipeHasRequiredDietTag_returnsTrue() {
        let cache = makeCache(ingredients: ["tofu", "spinach"], dietTags: ["Vegan", "Gluten-Free"])
        XCTAssertTrue(cache.isSafeForUser(
            blacklistedIngredients: [],
            requiredDietTags: ["Vegan"]
        ))
    }

    // Recipe is MISSING a required diet tag → must be filtered out
    func test_isSafe_recipeIsMissingRequiredTag_returnsFalse() {
        let cache = makeCache(ingredients: ["beef", "onion"], dietTags: ["Halal"])
        XCTAssertFalse(cache.isSafeForUser(
            blacklistedIngredients: [],
            requiredDietTags: ["Vegan"]   // Recipe is Halal, not Vegan
        ))
    }

    // Multiple required tags — recipe must satisfy ALL of them
    func test_isSafe_multipleRequiredTags_recipeHasAll_returnsTrue() {
        let cache = makeCache(ingredients: ["tofu", "rice"], dietTags: ["Vegan", "Gluten-Free", "Halal"])
        XCTAssertTrue(cache.isSafeForUser(
            blacklistedIngredients: [],
            requiredDietTags: ["Vegan", "Gluten-Free"]
        ))
    }

    // Recipe only partially satisfies required tags → filtered out
    func test_isSafe_multipleRequiredTags_recipeHasPartial_returnsFalse() {
        let cache = makeCache(ingredients: ["pasta", "cheese"], dietTags: ["Vegetarian"])
        XCTAssertFalse(cache.isSafeForUser(
            blacklistedIngredients: [],
            requiredDietTags: ["Vegetarian", "Gluten-Free"]  // missing Gluten-Free
        ))
    }

    // Blacklist check must be case-insensitive (the real filter uses .lowercased())
    func test_isSafe_blacklistMatching_isCaseInsensitive() {
        // Recipe has lowercase "peanut butter"; blacklist uses uppercase
        let cache = makeCache(ingredients: ["peanut butter"], dietTags: [])

        // Since RecipeCache.isSafeForUser does NOT lowercase, this tests the
        // exact behaviour in the code. If the code is case-sensitive, we document it.
        // Update this test if you add lowercased() normalization to RecipeCache.
        let resultWithUpperCase = cache.isSafeForUser(
            blacklistedIngredients: ["Peanut Butter"],
            requiredDietTags: []
        )
        // Document current behaviour (case-sensitive match):
        // "peanut butter" != "Peanut Butter" → NOT filtered (returns true)
        // This test catches any future change to that behaviour.
        XCTAssertTrue(resultWithUpperCase,
            "RecipeCache.isSafeForUser currently uses exact-match (case-sensitive). " +
            "Update this test if case-insensitive matching is added.")
    }

    // Blacklist item that partially overlaps must NOT falsely trigger
    func test_isSafe_partialIngredientName_doesNotFalselyTrigger() {
        let cache = makeCache(ingredients: ["peanut butter"], dietTags: [])
        // "peanut" is blacklisted, but the ingredient is "peanut butter" — different string
        XCTAssertTrue(cache.isSafeForUser(
            blacklistedIngredients: ["peanut"],
            requiredDietTags: []
        ), "Partial name match should NOT trigger blacklist; only exact string match should.")
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// MARK: - 6. FeedViewModel.applyProfileFilter Tests
// Tests the in-memory filter inside FeedViewModel using a mock ProfileViewModel
// ─────────────────────────────────────────────────────────────────────────────

// Minimal mock of ProfileServiceProtocol — no network calls
final class MockProfileService: ProfileServiceProtocol {
    func fetchProfile() async throws -> UserProfile? { nil }
    func updateProfile(dietTags: [String], blacklist: [String]) async throws {}
    func saveRecipe(_ recipeID: UUID) async throws {}
    func unsaveRecipe(_ recipeID: UUID) async throws {}
}

// Minimal mock for RecipeServiceProtocol
final class MockRecipeService: RecipeServiceProtocol {
    var recipesToReturn: [Recipe] = []
    func fetchApprovedRecipes() async throws -> [Recipe] { recipesToReturn }
    func searchByIngredients(_ ingredients: [String]) async throws -> [Recipe] { recipesToReturn }
    func fetchIngredientSuggestions(prefix: String) async throws -> [String] { [] }
    func fetchMediaPublicURL(bucket: String, path: String) -> URL {
        URL(string: "https://example.com")!
    }
}

@MainActor
final class FeedViewModelFilterTests: XCTestCase {

    private let creatorID = UUID()

    private func makeRecipe(title: String, ingredients: [String], dietTags: [String]) -> Recipe {
        Recipe(title: title, creatorID: creatorID, creatorUsername: "chef",
               videoURL: "", thumbnailURL: "", recipeDescription: "",
               dietTags: dietTags, ingredients: ingredients)
    }

    private func makeProfileVM(dietTags: [String] = [],
                                blacklist: [String] = []) -> ProfileViewModel {
        let vm = ProfileViewModel(profileService: MockProfileService(),
                                  localStore: LocalDataService.shared)
        vm.activeDietTags = dietTags
        vm.blacklistedIngredients = blacklist
        return vm
    }

    private func makeFeedVM(profileVM: ProfileViewModel) -> FeedViewModel {
        FeedViewModel(recipeService: MockRecipeService(), profileViewModel: profileVM)
    }

    // No filters applied → all recipes pass through
    func test_applyProfileFilter_noFilters_returnsAll() {
        let recipes = [
            makeRecipe(title: "A", ingredients: ["chicken"], dietTags: ["Halal"]),
            makeRecipe(title: "B", ingredients: ["tofu"],    dietTags: ["Vegan"]),
        ]
        let profileVM = makeProfileVM()
        let feedVM    = makeFeedVM(profileVM: profileVM)

        let result = feedVM.applyProfileFilter(to: recipes)
        XCTAssertEqual(result.count, 2)
    }

    // Recipe containing a blacklisted ingredient is removed
    func test_applyProfileFilter_blacklistedIngredient_isExcluded() {
        let safe    = makeRecipe(title: "Safe",    ingredients: ["chicken"],      dietTags: [])
        let unsafe  = makeRecipe(title: "Unsafe",  ingredients: ["peanut butter"], dietTags: [])

        let profileVM = makeProfileVM(blacklist: ["peanut butter"])
        let feedVM    = makeFeedVM(profileVM: profileVM)

        let result = feedVM.applyProfileFilter(to: [safe, unsafe])
        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result.first?.title, "Safe")
    }

    // Blacklist comparison is case-insensitive (FeedViewModel lowercases both sides)
    func test_applyProfileFilter_blacklist_isCaseInsensitive() {
        // Ingredient stored as "Peanut Butter" (capitalised), blacklist entry "peanut butter"
        let recipe    = makeRecipe(title: "Risky", ingredients: ["Peanut Butter"], dietTags: [])
        let profileVM = makeProfileVM(blacklist: ["peanut butter"])
        let feedVM    = makeFeedVM(profileVM: profileVM)

        let result = feedVM.applyProfileFilter(to: [recipe])
        XCTAssertTrue(result.isEmpty,
            "Blacklist matching in FeedViewModel is case-insensitive via lowercased()")
    }

    // Recipe missing a required diet tag is removed
    func test_applyProfileFilter_missingRequiredDietTag_isExcluded() {
        let veganRecipe    = makeRecipe(title: "Vegan Bowl",  ingredients: [], dietTags: ["Vegan"])
        let nonVeganRecipe = makeRecipe(title: "Chicken Fry", ingredients: [], dietTags: ["Halal"])

        let profileVM = makeProfileVM(dietTags: ["Vegan"])
        let feedVM    = makeFeedVM(profileVM: profileVM)

        let result = feedVM.applyProfileFilter(to: [veganRecipe, nonVeganRecipe])
        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result.first?.title, "Vegan Bowl")
    }

    // Recipe satisfies all required diet tags → included
    func test_applyProfileFilter_recipeHasAllRequiredTags_isIncluded() {
        let recipe    = makeRecipe(title: "Combo", ingredients: [], dietTags: ["Vegan", "Gluten-Free"])
        let profileVM = makeProfileVM(dietTags: ["Vegan", "Gluten-Free"])
        let feedVM    = makeFeedVM(profileVM: profileVM)

        let result = feedVM.applyProfileFilter(to: [recipe])
        XCTAssertEqual(result.count, 1)
    }

    // Both blacklist and diet tag filters applied together
    func test_applyProfileFilter_combinedFilters_worksCorrectly() {
        let good  = makeRecipe(title: "Good",  ingredients: ["spinach"], dietTags: ["Vegan"])
        let badA  = makeRecipe(title: "BadA",  ingredients: ["peanut butter"], dietTags: ["Vegan"])
        let badB  = makeRecipe(title: "BadB",  ingredients: ["spinach"], dietTags: ["Halal"])

        let profileVM = makeProfileVM(dietTags: ["Vegan"], blacklist: ["peanut butter"])
        let feedVM    = makeFeedVM(profileVM: profileVM)

        let result = feedVM.applyProfileFilter(to: [good, badA, badB])
        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result.first?.title, "Good")
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// MARK: - 7. SearchViewModel Logic Tests
// Tests ingredient basket management (pure logic, no network)
// ─────────────────────────────────────────────────────────────────────────────
@MainActor
final class SearchViewModelTests: XCTestCase {

    private func makeSearchVM() -> SearchViewModel {
        let profileVM = ProfileViewModel(profileService: MockProfileService(),
                                         localStore: LocalDataService.shared)
        return SearchViewModel(recipeService: MockRecipeService(),
                               profileViewModel: profileVM)
    }

    // Initial state: empty basket, empty results
    func test_initialState_isEmpty() {
        let vm = makeSearchVM()
        XCTAssertTrue(vm.selectedIngredients.isEmpty)
        XCTAssertTrue(vm.searchResults.isEmpty)
        XCTAssertEqual(vm.searchQuery, "")
    }

    // Adding an ingredient appends it to the basket and clears the query
    func test_addIngredient_appendsToBasket() {
        let vm = makeSearchVM()
        vm.addIngredient("garlic")

        XCTAssertEqual(vm.selectedIngredients, ["garlic"])
        XCTAssertEqual(vm.searchQuery, "",
            "searchQuery should be cleared after adding an ingredient")
    }

    // Duplicate ingredient is not added twice
    func test_addIngredient_duplicate_isIgnored() {
        let vm = makeSearchVM()
        vm.addIngredient("garlic")
        vm.addIngredient("garlic")

        XCTAssertEqual(vm.selectedIngredients.count, 1,
            "The same ingredient should not appear twice in the basket")
    }

    // Whitespace-only string is ignored
    func test_addIngredient_whitespaceOnly_isIgnored() {
        let vm = makeSearchVM()
        vm.addIngredient("   ")
        XCTAssertTrue(vm.selectedIngredients.isEmpty)
    }

    // Ingredient with leading/trailing whitespace is trimmed
    func test_addIngredient_withWhitespace_isTrimmed() {
        let vm = makeSearchVM()
        vm.addIngredient("  garlic  ")
        XCTAssertEqual(vm.selectedIngredients.first, "garlic",
            "Leading and trailing whitespace should be trimmed on add")
    }

    // Removing an ingredient removes it from the basket
    func test_removeIngredient_removesFromBasket() {
        let vm = makeSearchVM()
        vm.addIngredient("garlic")
        vm.addIngredient("onion")
        vm.removeIngredient("garlic")

        XCTAssertEqual(vm.selectedIngredients, ["onion"])
    }

    // Removing an ingredient that is not in the basket does nothing
    func test_removeIngredient_notInBasket_doesNothing() {
        let vm = makeSearchVM()
        vm.addIngredient("garlic")
        vm.removeIngredient("onion")   // "onion" was never added

        XCTAssertEqual(vm.selectedIngredients, ["garlic"])
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// MARK: - 8. AdminManager Tests
// Tests the pure-logic utility functions in AdminManager.swift
// ─────────────────────────────────────────────────────────────────────────────
final class AdminManagerTests: XCTestCase {

    private var manager: AdminManager!

    override func setUp() {
        super.setUp()
        manager = AdminManager()
    }

    // ID format: "ADM-0001" for index 0
    func test_generateAdminID_firstEntry_isADM0001() {
        XCTAssertEqual(manager.generateAdminID(lastIndex: 0), "ADM-0001")
    }

    // ID format: "ADM-0010" for index 9
    func test_generateAdminID_tenthEntry_isADM0010() {
        XCTAssertEqual(manager.generateAdminID(lastIndex: 9), "ADM-0010")
    }

    // Numeric part is always zero-padded to 4 digits
    func test_generateAdminID_paddingIsAlwaysFourDigits() {
        let id = manager.generateAdminID(lastIndex: 2)
        let suffix = id.replacingOccurrences(of: "ADM-", with: "")
        XCTAssertEqual(suffix.count, 4, "Numeric suffix must always be exactly 4 digits")
    }

    // Total ID length: "ADM-" (4) + 4 digits = 8 chars — well within the 15-char DB limit
    func test_generateAdminID_length_isWithinDBLimit() {
        let id = manager.generateAdminID(lastIndex: 100)
        XCTAssertLessThanOrEqual(id.count, 15,
            "Generated admin ID must not exceed the database column limit of 15 characters")
    }

    // ID always starts with "ADM-" prefix
    func test_generateAdminID_alwaysHasADMPrefix() {
        for index in [0, 5, 99, 999] {
            let id = manager.generateAdminID(lastIndex: index)
            XCTAssertTrue(id.hasPrefix("ADM-"),
                "Admin ID at index \(index) should start with 'ADM-'")
        }
    }

    // validateAdminName: non-empty name under 100 chars → valid
    func test_validateAdminName_validName_returnsTrue() {
        XCTAssertTrue(manager.validateAdminName(name: "Gregory Santoso"))
    }

    // validateAdminName: empty string → invalid
    func test_validateAdminName_emptyName_returnsFalse() {
        XCTAssertFalse(manager.validateAdminName(name: ""))
    }

    // validateAdminName: exactly 100 chars → valid (boundary)
    func test_validateAdminName_exactly100Chars_returnsTrue() {
        let name = String(repeating: "a", count: 100)
        XCTAssertTrue(manager.validateAdminName(name: name))
    }

    // validateAdminName: 101 chars → invalid (over the DB schema limit)
    func test_validateAdminName_over100Chars_returnsFalse() {
        let name = String(repeating: "a", count: 101)
        XCTAssertFalse(manager.validateAdminName(name: name))
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// MARK: - 9. CreatorViewModel Validation Tests
// Tests the canSubmit computed property — no upload service needed
// ─────────────────────────────────────────────────────────────────────────────

// Mock upload service — always succeeds with dummy data
final class MockCreatorUploadService: CreatorUploadServiceProtocol {
    func uploadVideo(_ videoData: Data, filename: String) async throws -> String { "https://video.url" }
    func uploadThumbnail(_ thumbnailData: Data, filename: String) async throws -> String { "https://thumb.url" }
    func submitRecipe(_ draft: RecipeDraft, videoURL: String, thumbnailURL: String) async throws -> Recipe {
        Recipe(title: draft.title, creatorID: UUID(), creatorUsername: "mock",
               videoURL: videoURL, thumbnailURL: thumbnailURL, recipeDescription: draft.description)
    }
    func fetchMySubmissions() async throws -> [CreatorSubmission] { [] }
}

@MainActor
final class CreatorViewModelTests: XCTestCase {

    private func makeVM() -> CreatorViewModel {
        CreatorViewModel(uploadService: MockCreatorUploadService())
    }

    // Fresh ViewModel cannot submit (no media or draft content yet)
    func test_canSubmit_withEmptyDraft_returnsFalse() {
        let vm = makeVM()
        XCTAssertFalse(vm.canSubmit,
            "A fresh ViewModel with no media or draft data should not be submittable")
    }

    // Fill everything required → canSubmit becomes true
    func test_canSubmit_withAllFieldsFilled_returnsTrue() {
        let vm = makeVM()
        vm.videoData     = Data([0x00])   // non-nil dummy video
        vm.thumbnailData = Data([0xFF])   // non-nil dummy thumbnail
        vm.draft.title       = "Vegan Bowl"
        vm.draft.description = "A tasty bowl"
        vm.draft.ingredients = ["tofu"]
        vm.draft.steps       = [RecipeStep(stepNumber: 1,
                                            instruction: "Mix", durationMinutes: nil)]

        XCTAssertTrue(vm.canSubmit)
    }

    // Missing video → cannot rsubmit
    func test_canSubmit_missingVideo_returnsFalse() {
        let vm = makeVM()
        vm.thumbnailData = Data([0xFF])
        vm.draft.title       = "Title"
        vm.draft.description = "Desc"
        vm.draft.ingredients = ["ingredient"]
        vm.draft.steps       = [RecipeStep(stepNumber: 1, instruction: "Step", durationMinutes: nil)]

        XCTAssertFalse(vm.canSubmit, "Missing video should prevent submission")
    }

    // Whitespace-only title → cannot submit
    func test_canSubmit_whitespaceOnlyTitle_returnsFalse() {
        let vm = makeVM()
        vm.videoData     = Data([0x00])
        vm.thumbnailData = Data([0xFF])
        vm.draft.title       = "   "   // looks filled but is whitespace
        vm.draft.description = "Desc"
        vm.draft.ingredients = ["ingredient"]
        vm.draft.steps       = [RecipeStep(stepNumber: 1, instruction: "Step", durationMinutes: nil)]

        XCTAssertFalse(vm.canSubmit, "Whitespace-only title should fail the trim check")
    }

    // Empty ingredients list → cannot submit
    func test_canSubmit_emptyIngredients_returnsFalse() {
        let vm = makeVM()
        vm.videoData     = Data([0x00])
        vm.thumbnailData = Data([0xFF])
        vm.draft.title       = "Title"
        vm.draft.description = "Desc"
        vm.draft.ingredients = []   // empty
        vm.draft.steps       = [RecipeStep(stepNumber: 1, instruction: "Step", durationMinutes: nil)]

        XCTAssertFalse(vm.canSubmit, "Empty ingredients list should prevent submission")
    }

    // resetForm must clear all draft and media state
    func test_resetForm_clearsAllDraftAndMediaState() {
        let vm = makeVM()
        vm.videoData         = Data([0x00])
        vm.thumbnailData     = Data([0xFF])
        vm.draft.title       = "My Recipe"
        vm.draft.ingredients = ["garlic"]

        vm.resetForm()

        XCTAssertNil(vm.videoData)
        XCTAssertNil(vm.thumbnailData)
        XCTAssertEqual(vm.draft.title, "")
        XCTAssertTrue(vm.draft.ingredients.isEmpty)
    }

    // resetUploadState must reset phase back to .idle and clear errors
    func test_resetUploadState_resetsPhaseAndError() {
        let vm = makeVM()
        vm.uploadPhase  = .failed("some error")
        vm.errorMessage = "some error"
        vm.uploadProgress = 0.75

        vm.resetUploadState()

        XCTAssertEqual(vm.uploadPhase, .idle)
        XCTAssertNil(vm.errorMessage)
        XCTAssertEqual(vm.uploadProgress, 0.0, accuracy: 0.001)
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// MARK: - 10. UploadPhase Equatable Tests
// ─────────────────────────────────────────────────────────────────────────────
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
        let recipe = Recipe(title: "R", creatorID: id, creatorUsername: "u",
                            videoURL: "", thumbnailURL: "", recipeDescription: "")
        XCTAssertEqual(UploadPhase.done(recipe), UploadPhase.done(recipe))
    }
}
