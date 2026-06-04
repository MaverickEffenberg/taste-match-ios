//
//  RecipeCache.swift
//  Taste Match
//
//  Created by GREGORY on 03/06/26.
//


import Foundation
import SwiftData

// Model database lokal yang super cepat
@Model
final class RecipeCache {
    @Attribute(.unique) var recipeID: UUID
    var title: String
    var creatorTag: String
    var ingredients: [String]
    var dietTags: [String]
    
    init(recipeID: UUID, title: String, creatorTag: String, ingredients: [String], dietTags: [String]) {
        self.recipeID = recipeID
        self.title = title
        self.creatorTag = creatorTag
        self.ingredients = ingredients
        self.dietTags = dietTags
    }
    
    // Logika Filtering Instan untuk Global Dietary Profile
    func isSafeForUser(blacklistedIngredients: [String], requiredDietTags: [String]) -> Bool {
        // 1. Cek Alergen/Blacklist (Exclude)
        let containsAllergen = ingredients.contains { ingredient in
            blacklistedIngredients.contains(ingredient)
        }
        if containsAllergen { return false }
        
        // 2. Cek Kepatuhan Diet (Include/Match Tag)
        let meetsDietaryRequirements = requiredDietTags.allSatisfy { tag in
            dietTags.contains(tag)
        }
        return meetsDietaryRequirements
    }
}