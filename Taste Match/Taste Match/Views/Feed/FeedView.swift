import SwiftUI
import AVFoundation
import AVKit
import Combine

// MARK: - Visible Item Detection

private struct CardMidYKey: PreferenceKey {
    static let defaultValue: [UUID: CGFloat] = [:]
    static func reduce(value: inout [UUID: CGFloat], nextValue: () -> [UUID: CGFloat]) {
        value.merge(nextValue()) { $1 }
    }
}

// MARK: - FeedView

struct FeedView: View {

    @ObservedObject var viewModel: FeedViewModel
    @ObservedObject var profileVM: ProfileViewModel

    @State private var activeID: UUID? = nil

    var body: some View {

        ZStack {

            Color.black.ignoresSafeArea()

            if viewModel.isLoading {

                ProgressView("Loading Feed…")
                    .foregroundColor(.white)

            } else if viewModel.visibleRecipes.isEmpty {

                EmptyFeedView()

            } else {

                GeometryReader { geo in

                    let screenMidY  = geo.frame(in: .global).midY
                    let recipes     = viewModel.visibleRecipes
                    let activeIndex = recipes.firstIndex { $0.id == activeID } ?? 0

                    ScrollView(.vertical, showsIndicators: false) {

                        LazyVStack(spacing: 0) {

                            ForEach(Array(recipes.enumerated()), id: \.element.id) { index, recipe in

                                RecipeVideoCard(
                                    recipe:   recipe,
                                    isActive: activeID == recipe.id,
                                    isLoaded: abs(index - activeIndex) <= 1,
                                    isSaved:  profileVM.isSaved(recipe),
                                    onSave:   { viewModel.saveRecipe(recipe) },
                                    onExpand: { viewModel.toggleExpansion() }
                                )
                                .frame(height: geo.size.height)
                                .background(
                                    GeometryReader { cardGeo in
                                        Color.clear.preference(
                                            key: CardMidYKey.self,
                                            value: [recipe.id: cardGeo.frame(in: .global).midY]
                                        )
                                    }
                                )
                            }
                        }
                    }
                    .scrollTargetBehavior(.paging)
                    .ignoresSafeArea()
                    .onPreferenceChange(CardMidYKey.self) { midYMap in
                        let winner = midYMap.min {
                            abs($0.value - screenMidY) < abs($1.value - screenMidY)
                        }
                        if let winner, winner.key != activeID {
                            activeID = winner.key
                        }
                    }
                }
                .ignoresSafeArea()

                // Expansion overlay — slides up when the user taps the list button.
                if viewModel.isExpanded, let recipe = viewModel.currentRecipe {
                    RecipeExpansionOverlay(
                        recipe:    recipe,
                        onDismiss: { viewModel.toggleExpansion() }
                    )
                    .transition(.move(edge: .bottom))
                    .animation(.spring(), value: viewModel.isExpanded)
                }
            }
        }
        .onChange(of: viewModel.visibleRecipes) { _, recipes in
            if activeID == nil { activeID = recipes.first?.id }
        }
        .onAppear {
            if activeID == nil { activeID = viewModel.visibleRecipes.first?.id }
        }
        .overlay(alignment: .top) {
            if let err = viewModel.errorMessage {
                ErrorToast(message: err).transition(.slide)
            }
        }
        .navigationTitle("Discover")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - RecipeVideoCard

struct RecipeVideoCard: View {

    let recipe:   Recipe
    let isActive: Bool
    let isLoaded: Bool
    let isSaved:  Bool
    let onSave:   () -> Void
    let onExpand: () -> Void

    var body: some View {

        ZStack(alignment: .bottomLeading) {

            RecipeVideoPlayer(recipe: recipe, isActive: isActive, isLoaded: isLoaded)

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

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack {
                            ForEach(recipe.dietTags, id: \.self) { tag in
                                DietTagBadge(tag: tag)
                            }
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

// MARK: - RecipeVideoPlayer

struct RecipeVideoPlayer: View {

    let recipe:   Recipe
    let isActive: Bool
    let isLoaded: Bool

    @StateObject private var manager = PlayerManager()

    var body: some View {

        ZStack {

            VideoPlayer(player: manager.player)
                .ignoresSafeArea()
                .background(Color.black)

            if !manager.isReady {
                VideoThumbnailView(thumbnailURL: recipe.thumbnailURL)
                    .overlay {
                        ZStack {
                            Color.black.opacity(0.4)
                            if manager.isFailed {
                                VStack(spacing: 12) {
                                    Image(systemName: "wifi.slash")
                                        .font(.largeTitle)
                                        .foregroundColor(.white)
                                    Text("Video failed to load")
                                        .foregroundColor(.white)
                                }
                            } else {
                                ProgressView().tint(.white)
                            }
                        }
                    }
            }
        }
        .task(id: recipe.id) {
            manager.configure(urlString: recipe.videoURL)
            manager.setActive(isActive)
        }
        .onChange(of: isActive) { _, active in
            manager.setActive(active)
        }
        .onChange(of: isLoaded) { _, loaded in
            if loaded {
                manager.configure(urlString: recipe.videoURL)
            } else {
                manager.unload()
            }
        }
        .onDisappear {
            manager.setActive(false)
        }
    }
}

// MARK: - PlayerManager

final class PlayerManager: ObservableObject {

    @Published private(set) var isReady  = false
    @Published private(set) var isFailed = false

    let player = AVPlayer()

    private var currentURL: String?
    private var wantsToPlay = false

    private var statusObserver:    NSKeyValueObservation?
    private var loopObserverToken: NSObjectProtocol?

    // MARK: Public API — main thread only

    func setActive(_ active: Bool) {
        wantsToPlay = active
        if active {
            startIfReady()
        } else {
            player.pause()
            player.seek(to: .zero)
        }
    }

    func configure(urlString: String) {
        guard urlString != currentURL else { return }

        currentURL  = urlString
        wantsToPlay = false
        isReady     = false
        isFailed    = false

        player.pause()
        clearLoopObserver()
        statusObserver?.invalidate()
        statusObserver = nil

        guard let url = URL(string: urlString) else {
            isFailed = true
            return
        }

        #if canImport(UIKit)
        try? AVAudioSession.sharedInstance().setCategory(
            .playback, mode: .moviePlayback, options: []
        )
        try? AVAudioSession.sharedInstance().setActive(true)
        #endif

        let item = AVPlayerItem(url: url)
        item.preferredForwardBufferDuration = 2
        player.replaceCurrentItem(with: item)
        player.isMuted = false

        statusObserver = item.observe(\.status, options: [.new, .initial]) { [weak self] observedItem, _ in
            let status = observedItem.status
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                switch status {
                case .readyToPlay:
                    self.loopObserverToken = NotificationCenter.default.addObserver(
                        forName: .AVPlayerItemDidPlayToEndTime,
                        object: observedItem,
                        queue: .main
                    ) { [weak self] _ in
                        self?.player.seek(to: .zero)
                        self?.player.play()
                    }
                    self.isReady = true
                    self.startIfReady()
                case .failed:
                    self.wantsToPlay = false
                    self.isFailed    = true
                default:
                    break
                }
            }
        }
    }

    func unload() {
        wantsToPlay = false
        isReady     = false
        isFailed    = false
        currentURL  = nil

        player.pause()
        clearLoopObserver()
        statusObserver?.invalidate()
        statusObserver = nil

        player.replaceCurrentItem(with: nil)
    }

    // MARK: Private

    private func startIfReady() {
        guard isReady, wantsToPlay else { return }
        player.play()
    }

    private func clearLoopObserver() {
        if let token = loopObserverToken {
            NotificationCenter.default.removeObserver(token)
            loopObserverToken = nil
        }
    }

    deinit {
        statusObserver?.invalidate()
        if let token = loopObserverToken {
            NotificationCenter.default.removeObserver(token)
        }
    }
}

// MARK: - Supporting Views

struct VideoThumbnailView: View {
    let thumbnailURL: String
    var body: some View {
        AsyncImage(url: URL(string: thumbnailURL)) { image in
            image.resizable().scaledToFill()
        } placeholder: {
            Rectangle().fill(Color.gray.opacity(0.3))
        }
        .ignoresSafeArea()
        .clipped()
    }
}

struct EmptyFeedView: View {
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "fork.knife.circle")
                .font(.system(size: 60))
                .foregroundColor(.white.opacity(0.6))
            Text("No recipes found")
                .font(.title3).bold()
                .foregroundColor(.white)
            Text("Try adjusting your dietary profile in Settings.")
                .font(.subheadline)
                .foregroundColor(.white.opacity(0.7))
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
