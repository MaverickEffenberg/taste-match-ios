
import SwiftUI

struct ProfileView: View {
    @ObservedObject var profileVM: ProfileViewModel
    @ObservedObject var authVM: AuthViewModel

    @State private var newBlacklistEntry: String = ""

    var body: some View {
        NavigationStack {
            Form {

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

            Button(action: onUnsave) {
                Image(systemName: "bookmark.slash")
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

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
