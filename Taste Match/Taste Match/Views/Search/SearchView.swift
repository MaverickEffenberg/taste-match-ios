import SwiftUI

// MARK: - Search View
// Ingredient-First Filter Search: users build a basket of ingredients
// they have at home; the view shows matching recipes ranked by overlap count.
// The Global Dietary Profile is applied on top of the results.
struct SearchView: View {
    @ObservedObject var viewModel: SearchViewModel
    @ObservedObject var profileVM: ProfileViewModel

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {

                // Search input + ingredient chips panel
                VStack(alignment: .leading, spacing: 10) {

                    // Text field with a clear button
                    HStack {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(.secondary)

                        TextField("Type an ingredient…", text: $viewModel.searchQuery)
                            .autocorrectionDisabled()
                            // Allow adding an ingredient by pressing Return
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

                    // Autocomplete suggestions fetched from master_ingredients
                    // using a 300 ms debounce to limit Supabase queries.
                    if !viewModel.suggestions.isEmpty {
                        SuggestionList(suggestions: viewModel.suggestions) { name in
                            viewModel.addIngredient(name)
                        }
                        .padding(.horizontal)
                    }

                    // Horizontal scrolling row of chips for selected ingredients.
                    // Tapping the × on a chip removes it and re-runs the search.
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

                // Results area — switches between states based on search status
                if viewModel.isSearching {
                    Spacer()
                    ProgressView("Searching…")
                    Spacer()

                } else if viewModel.selectedIngredients.isEmpty {
                    // Prompt shown before the user has entered any ingredients
                    SearchPromptView()

                } else if viewModel.searchResults.isEmpty {
                    NoResultsView()

                } else {
                    // Ranked result list — recipes with the most ingredient
                    // matches are sorted to the top by SearchViewModel.
                    List(viewModel.searchResults) { recipe in
                        RecipeSearchRow(
                            recipe: recipe,
                            isSaved: profileVM.isSaved(recipe)
                        ) {
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

// MARK: - Suggestion Dropdown

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

// MARK: - Ingredient Chip
// Tappable pill showing a selected ingredient. The × removes it from
// the search basket and triggers a new search automatically.
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

// MARK: - Recipe Search Row
// Compact list row used in search results, matching the style of the
// Playlist tab rows for visual consistency.
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

// MARK: - Empty/Prompt States

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
