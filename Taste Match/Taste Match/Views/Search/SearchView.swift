
import SwiftUI

struct SearchView: View {
    @ObservedObject var viewModel: SearchViewModel
    @ObservedObject var profileVM: ProfileViewModel

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {

                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(.secondary)

                        TextField("Type an ingredient…", text: $viewModel.searchQuery)
                            .autocorrectionDisabled()
                            .onSubmit {
                                viewModel.addIngredient(viewModel.searchQuery)
                            }

                        if !viewModel.searchQuery.isEmpty {
                            Button(action: { viewModel.searchQuery = "" }) {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    .padding(10)
                    .background(Color.gray.opacity(0.15))
                    .cornerRadius(10)
                    .padding(.horizontal)

                    if !viewModel.suggestions.isEmpty {
                        SuggestionList(suggestions: viewModel.suggestions) { name in
                            viewModel.addIngredient(name)
                        }
                        .padding(.horizontal)
                    }

                    if !viewModel.selectedIngredients.isEmpty {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack {
                                ForEach(viewModel.selectedIngredients, id: \.self) { ingredient in
                                    IngredientChip(name: ingredient) {
                                        viewModel.removeIngredient(ingredient)
                                    }
                                }
                            }
                            .padding(.horizontal)
                        }
                    }
                }
                .padding(.vertical, 10)
                .background(Color.gray.opacity(0.15))

                Divider()

                if viewModel.isSearching {
                    Spacer()
                    ProgressView("Searching…")
                    Spacer()

                } else if viewModel.selectedIngredients.isEmpty {
                    SearchPromptView()

                } else if viewModel.searchResults.isEmpty {
                    NoResultsView()

                } else {
                    List(viewModel.searchResults) { recipe in
                        RecipeSearchRow(recipe: recipe, isSaved: profileVM.isSaved(recipe)) {
                            profileVM.saveRecipe(recipe)
                        }
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("Search by Ingredients")
        }
    }
}

struct SuggestionList: View {
    let suggestions: [String]
    let onSelect: (String) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(suggestions, id: \.self) { suggestion in
                Button(action: { onSelect(suggestion) }) {
                    HStack {
                        Image(systemName: "plus.circle")
                            .foregroundColor(.accentColor)
                        Text(suggestion.capitalized)
                            .foregroundColor(.primary)
                    }
                    .padding(.vertical, 8)
                    .padding(.horizontal, 12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                Divider()
            }
        }
        .background(Color.gray.opacity(0.15))
        .cornerRadius(8)
        .shadow(radius: 4)
    }
}

struct IngredientChip: View {
    let name: String
    let onRemove: () -> Void

    var body: some View {
        HStack(spacing: 4) {
            Text(name.capitalized)
                .font(.subheadline)
            Button(action: onRemove) {
                Image(systemName: "xmark")
                    .font(.caption2)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Color.accentColor.opacity(0.15))
        .foregroundColor(.accentColor)
        .clipShape(Capsule())
    }
}

struct RecipeSearchRow: View {
    let recipe: Recipe
    let isSaved: Bool
    let onSave: () -> Void

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
                    .font(.headline)
                    .lineLimit(1)

                Text("@\(recipe.creatorUsername)")
                    .font(.caption)
                    .foregroundColor(.secondary)

                HStack {
                    ForEach(recipe.dietTags, id: \.self) { tag in
                        DietTagBadge(tag: tag)
                    }
                }
            }

            Spacer()

            Button(action: onSave) {
                Image(systemName: isSaved ? "bookmark.fill" : "bookmark")
                    .foregroundColor(isSaved ? .yellow : .secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

struct SearchPromptView: View {
    var body: some View {
        VStack(spacing: 12) {
            Spacer()
            Image(systemName: "refrigerator")
                .font(.system(size: 50))
                .foregroundColor(.secondary)
            Text("What's in your fridge?")
                .font(.title3).bold()
            Text("Type ingredients above to find recipes that use what you already have.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            Spacer()
        }
    }
}

struct NoResultsView: View {
    var body: some View {
        VStack(spacing: 12) {
            Spacer()
            Image(systemName: "questionmark.circle")
                .font(.system(size: 50))
                .foregroundColor(.secondary)
            Text("No recipes found")
                .font(.title3).bold()
            Text("Try removing an ingredient or adjusting your dietary profile.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            Spacer()
        }
    }
}
