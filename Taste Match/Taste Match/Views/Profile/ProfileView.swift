import SwiftUI

// MARK: - Profile View
// Houses the Global Dietary & Allergen Profile settings. Every change here
// is persisted immediately to both SwiftData (local) and Supabase (remote)
// and automatically propagates to the feed and search filters.
struct ProfileView: View {
    @ObservedObject var profileVM: ProfileViewModel
    @ObservedObject var authVM: AuthViewModel

    @State private var newBlacklistEntry: String = ""

    var body: some View {
        NavigationStack {
            Form {

                // Diet tag toggles — each toggle calls profileVM.toggleDietTag
                // which updates activeDietTags and persists to Supabase.
                Section {
                    ForEach(DietTag.allCases) { tag in
                        Toggle(tag.rawValue, isOn: Binding(
                            get: { profileVM.activeDietTags.contains(tag.rawValue) },
                            set: { _ in profileVM.toggleDietTag(tag.rawValue) }
                        ))
                    }
                } header: {
                    Text("Dietary Preferences")
                } footer: {
                    Text("Only recipes matching ALL selected tags will appear in your feed and search results.")
                }

                // Allergen / blacklist management section.
                // Entries are normalised to lowercase before storage so
                // "Peanuts", "peanuts", and "PEANUTS" all match the same ingredient.
                Section {
                    HStack {
                        TextField("e.g. peanuts, shellfish", text: $newBlacklistEntry)
                            .autocorrectionDisabled()
                        Button("Add") {
                            profileVM.addBlacklistedIngredient(newBlacklistEntry)
                            newBlacklistEntry = ""
                        }
                        .disabled(newBlacklistEntry.trimmingCharacters(in: .whitespaces).isEmpty)
                    }

                    ForEach(profileVM.blacklistedIngredients, id: \.self) { ingredient in
                        HStack {
                            Image(systemName: "nosign")
                                .foregroundColor(.red)
                            Text(ingredient.capitalized)
                        }
                    }
                    // Swipe-to-delete support on the blacklist rows
                    .onDelete { indexSet in
                        indexSet.forEach { i in
                            let name = profileVM.blacklistedIngredients[i]
                            profileVM.removeBlacklistedIngredient(name)
                        }
                    }

                } header: {
                    Text("Allergens & Disliked Ingredients")
                } footer: {
                    Text("Recipes containing these ingredients will be completely hidden from your feed.")
                }

                // Account info and sign-out
                Section("Account") {
                    if let user = authVM.currentUser {
                        LabeledContent("Username", value: user.username)
                        LabeledContent("Email", value: user.email)
                        LabeledContent("Role", value: user.role.capitalized)
                    }

                    Button(role: .destructive) {
                        Task { await authVM.signOut() }
                    } label: {
                        Text("Sign Out")
                    }
                }
            }
            .navigationTitle("My Profile")
        }
    }
}

// MARK: - Playlist View
// Displays the user's saved recipe collection (the "Saved" playlist).
// Recipes are saved locally via SwiftData and synced to Supabase so the
// playlist is available across devices.
struct PlaylistView: View {
    @ObservedObject var profileVM: ProfileViewModel

    var body: some View {
        NavigationStack {
            Group {
                if profileVM.savedRecipes.isEmpty {
                    EmptyPlaylistView()
                } else {
                    List {
                        ForEach(profileVM.savedRecipes) { recipe in
                            // Each row includes an unsave button that removes
                            // the recipe from both the local cache and Supabase.
                            SavedRecipeRow(recipe: recipe) {
                                profileVM.unsaveRecipe(recipe)
                            }
                        }
                    }
                    #if os(iOS)
                    .listStyle(.insetGrouped)
                    #else
                    .listStyle(.inset)
                    #endif
                }
            }
            .navigationTitle("Saved Recipes")
        }
    }
}

// MARK: - Saved Recipe Row

struct SavedRecipeRow: View {
    let recipe: Recipe
    let onUnsave: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            AsyncImage(url: URL(string: recipe.thumbnailURL)) { img in
                img.resizable().scaledToFill()
            } placeholder: {
                Rectangle().fill(Color.gray.opacity(0.3))
            }
            .frame(width: 70, height: 70)
            .cornerRadius(8)
            .clipped()

            VStack(alignment: .leading, spacing: 4) {
                Text(recipe.title)
                    .font(.headline).lineLimit(1)
                Text("@\(recipe.creatorUsername)")
                    .font(.caption).foregroundColor(.secondary)
                HStack {
                    ForEach(recipe.dietTags, id: \.self) { DietTagBadge(tag: $0) }
                }
            }

            Spacer()

            // Bookmark-slash icon removes the recipe from the playlist
            Button(action: onUnsave) {
                Image(systemName: "bookmark.slash")
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Empty Playlist State

struct EmptyPlaylistView: View {
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "bookmark.slash")
                .font(.system(size: 50))
                .foregroundColor(.secondary)
            Text("No saved recipes yet")
                .font(.title3).bold()
            Text("Tap the bookmark icon on any recipe to save it here.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
    }
}
