import SwiftUI

struct SavedPlaylistView: View {
    // Menarik data langsung dari ViewModel yang sudah kamu buat, bukan dummy!
    @EnvironmentObject var profileVM: ProfileViewModel
    
    var body: some View {
        NavigationStack {
            Group {
                if profileVM.savedRecipes.isEmpty {
                    VStack(spacing: 20) {
                        Image(systemName: "bookmark.slash")
                            .font(.system(size: 50))
                            .foregroundColor(.gray)
                        Text("Koleksimu masih kosong, mon cher.")
                            .font(.headline)
                            .foregroundColor(.secondary)
                    }
                } else {
                    List {
                        // Menampilkan data RESEP ASLI dari Supabase/SwiftData!
                        ForEach(profileVM.savedRecipes) { recipe in
                            SavedRecipeRow(
                                recipe: recipe,
                                onUnsave: { profileVM.unsaveRecipe(recipe) }
                            )
                        }
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("Saved Playlist")
        }
    }
}

// Baris yang sudah di-upgrade ke data nyata
