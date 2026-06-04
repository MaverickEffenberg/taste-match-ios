import SwiftUI
import AVKit

struct FeedView: View {
    @ObservedObject var viewModel: FeedViewModel
    @ObservedObject var profileVM: ProfileViewModel

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if viewModel.isLoading {
                ProgressView("Loading Feed…")
                    .foregroundColor(.white)

            } else if viewModel.visibleRecipes.isEmpty {
                EmptyFeedView()

            } else {
                ScrollView(.vertical, showsIndicators: false) {
                    LazyVStack(spacing: 0) {
                        ForEach(Array(viewModel.visibleRecipes.enumerated()), id: \.element.id) { index, recipe in
                            RecipeVideoCard(
                                recipe: recipe,
                                isSaved: profileVM.isSaved(recipe),
                                onSave: { viewModel.saveRecipe(recipe) },
                                onExpand: { viewModel.toggleExpansion() }
                            )
                            .containerRelativeFrame([.horizontal, .vertical])
                            .onAppear { viewModel.currentIndex = index }
                        }
                    }
                    .scrollTargetLayout()
                }
                .scrollTargetBehavior(.paging)
                #if os(iOS)
                .ignoresSafeArea()
                #endif
                .ignoresSafeArea()

                if viewModel.isExpanded, let recipe = viewModel.currentRecipe {
                    RecipeExpansionOverlay(recipe: recipe, onDismiss: { viewModel.toggleExpansion() })
                        .transition(.move(edge: .bottom))
                        .animation(.spring(), value: viewModel.isExpanded)
                }
            }
        }
        .overlay(alignment: .top) {
            if let err = viewModel.errorMessage {
                ErrorToast(message: err)
                    .transition(.slide)
            }
        }
        .navigationTitle("Discover")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
    }
}

// MARK: - RecipeVideoCard

struct RecipeVideoCard: View {
    let recipe: Recipe
    let isSaved: Bool
    let onSave: () -> Void
    let onExpand: () -> Void

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            // Voilà! Menggunakan pemutar video asli, bukan sekadar thumbnail mati
            RecipeVideoPlayer(recipe: recipe)

            LinearGradient(
                colors: [.clear, .black.opacity(0.75)],
                startPoint: .center,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            HStack(alignment: .bottom) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("@\(recipe.creatorUsername)")
                        .font(.subheadline).bold()
                        .foregroundColor(.white)

                    Text(recipe.title)
                        .font(.title3).bold()
                        .foregroundColor(.white)
                        .lineLimit(2)

                    Text(recipe.recipeDescription)
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.85))
                        .lineLimit(2)

                    HStack {
                        ForEach(recipe.dietTags, id: \.self) { tag in
                            DietTagBadge(tag: tag)
                        }
                    }
                }

                Spacer()

                VStack(spacing: 20) {
                    Button(action: onSave) {
                        Image(systemName: isSaved ? "bookmark.fill" : "bookmark")
                            .font(.title2)
                            .foregroundColor(isSaved ? .yellow : .white)
                    }

                    Button(action: onExpand) {
                        Image(systemName: "list.bullet.rectangle")
                            .font(.title2)
                            .foregroundColor(.white)
                    }
                }
                .padding(.bottom, 8)
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 100)
        }
    }
}

// MARK: - RecipeVideoPlayer (Sang Bintang Utama)

struct RecipeVideoPlayer: View {
    let recipe: Recipe
    @State private var player: AVPlayer?
    
    var body: some View {
        ZStack {
            if let player = player {
                VideoPlayer(player: player)
                    .edgesIgnoringSafeArea(.all)
                    // Pemutar video murni yang otomatis berjalan
                    .onAppear { player.play() }
                    .onDisappear { player.pause() }
            } else {
                // Menampilkan thumbnail cantik saat video masih ditarik dari awan
                VideoThumbnailView(thumbnailURL: recipe.thumbnailURL)
                    .overlay(Color.black.opacity(0.3))
                    .overlay(ProgressView().tint(.white))
            }
        }
        .onAppear {
            let service = SupabaseRecipeService()
            // Menarik URL asli dari Supabase Storage!
            let url = service.fetchMediaPublicURL(bucket: "recipe-videos", path: recipe.videoURL)
            self.player = AVPlayer(url: url)
        }
    }
}

// MARK: - VideoThumbnailView

struct VideoThumbnailView: View {
    let thumbnailURL: String

    var body: some View {
        AsyncImage(url: URL(string: thumbnailURL)) { image in
            image.resizable().scaledToFill()
        } placeholder: {
            Rectangle().fill(Color.gray.opacity(0.4))
                .overlay(Image(systemName: "play.fill").foregroundColor(.white).font(.largeTitle))
        }
        .ignoresSafeArea()
        .clipped()
    }
}

// MARK: - RecipeExpansionOverlay



// MARK: - Supporting Views

struct EmptyFeedView: View {
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "fork.knife.circle")
                .font(.system(size: 60))
                .foregroundColor(.white.opacity(0.6))
            Text("No recipes found")
                .font(.title3).bold().foregroundColor(.white)
            Text("Try adjusting your dietary profile in Settings.")
                .font(.subheadline).foregroundColor(.white.opacity(0.7))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
    }
}

struct DietTagBadge: View {
    let tag: String

    var body: some View {
        Text(tag)
            .font(.caption2).bold()
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(Color.green.opacity(0.85))
            .foregroundColor(.white)
            .clipShape(Capsule())
    }
}

struct ErrorToast: View {
    let message: String

    var body: some View {
        Text(message)
            .font(.caption)
            .padding(10)
            .background(Color.red.opacity(0.9))
            .foregroundColor(.white)
            .cornerRadius(8)
            .padding(.top, 60)
    }
}
