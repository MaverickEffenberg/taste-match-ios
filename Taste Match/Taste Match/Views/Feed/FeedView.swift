import SwiftUI
import AVKit
import AVFoundation
import Combine

// MARK: - FeedView

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
                GeometryReader { geo in
                    ScrollView(.vertical, showsIndicators: false) {
                        LazyVStack(spacing: 0) {
                            ForEach(Array(viewModel.visibleRecipes.enumerated()), id: \.element.id) { index, recipe in
                                RecipeVideoCard(
                                    recipe: recipe,
                                    isActive: viewModel.currentIndex == index,
                                    isSaved: profileVM.isSaved(recipe),
                                    onSave: { viewModel.saveRecipe(recipe) },
                                    onExpand: { viewModel.toggleExpansion() }
                                )
                                // GeometryReader-based full-screen sizing works on
                                // iOS 16, macOS 13 and later (unlike containerRelativeFrame
                                // which requires iOS 17 / macOS 14).
                                .frame(width: geo.size.width, height: geo.size.height)
                                .onAppear { viewModel.currentIndex = index }
                            }
                        }
                        // scrollTargetLayout + scrollTargetBehavior(.paging) require
                        // iOS 17 / macOS 14. Use them when available; fall back to
                        // plain scrolling on older OS versions.
                        .if_available_scrollTargetLayout()
                    }
                    .if_available_pagingBehavior()
                    .ignoresSafeArea()
                }
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

// MARK: - Scroll modifier helpers
// These ViewModifiers apply the iOS 17 / macOS 14 paging APIs when available
// and are no-ops on older OS versions, keeping the code clean at the call site.

private extension View {
    @ViewBuilder
    func if_available_scrollTargetLayout() -> some View {
        if #available(iOS 17, macOS 14, *) {
            self.scrollTargetLayout()
        } else {
            self
        }
    }

    @ViewBuilder
    func if_available_pagingBehavior() -> some View {
        if #available(iOS 17, macOS 14, *) {
            self.scrollTargetBehavior(.paging)
        } else {
            self
        }
    }
}

// MARK: - RecipeVideoCard

struct RecipeVideoCard: View {
    let recipe: Recipe
    let isActive: Bool
    let isSaved: Bool
    let onSave: () -> Void
    let onExpand: () -> Void

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            RecipeVideoPlayer(recipe: recipe, isActive: isActive)

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

// MARK: - RecipeVideoPlayer

struct RecipeVideoPlayer: View {
    let recipe: Recipe
    let isActive: Bool

    @StateObject private var holder = VideoPlayerHolder()

    var body: some View {
        ZStack {
            if holder.isReady {
                VideoLayerView(player: holder.player)
                    .ignoresSafeArea()
            } else {
                VideoThumbnailView(thumbnailURL: recipe.thumbnailURL)
                    .overlay(Color.black.opacity(0.3))
                    .overlay(
                        Group {
                            if holder.isFailed {
                                VStack(spacing: 8) {
                                    Image(systemName: "exclamationmark.triangle.fill")
                                        .font(.largeTitle)
                                        .foregroundColor(.white.opacity(0.7))
                                    Text("Video unavailable")
                                        .font(.caption)
                                        .foregroundColor(.white.opacity(0.7))
                                }
                            } else {
                                ProgressView().tint(.white)
                            }
                        }
                    )
            }
        }
        .task(id: recipe.id) {
            await holder.load(videoURL: recipe.videoURL)
        }
        // Two-argument form works on iOS 16 / macOS 13+
        // (single-argument form requires iOS 17 / macOS 14)
        .onChange(of: isActive) { _, active in
            active ? holder.play() : holder.pause()
        }
        .onAppear {
            if isActive { holder.play() }
        }
        .onDisappear {
            holder.pause()
        }
    }
}

// MARK: - VideoPlayerHolder

@MainActor
final class VideoPlayerHolder: ObservableObject {
    @Published var isReady:  Bool = false
    @Published var isFailed: Bool = false

    private(set) var player = AVQueuePlayer()
    private var looper:         AVPlayerLooper?
    private var statusObserver: NSKeyValueObservation?

    func load(videoURL: String) async {
        statusObserver?.invalidate()
        statusObserver = nil
        looper = nil
        player.removeAllItems()
        isReady  = false
        isFailed = false

        guard let url = URL(string: videoURL) else {
            print("[VideoPlayer] Bad URL: \(videoURL)")
            isFailed = true
            return
        }

        print("[VideoPlayer] Loading: \(url)")
        guard !Task.isCancelled else { return }

        #if canImport(UIKit)
        try? AVAudioSession.sharedInstance().setCategory(
            .playback, mode: .moviePlayback, options: [.mixWithOthers]
        )
        try? AVAudioSession.sharedInstance().setActive(true)
        #endif

        let item = AVPlayerItem(url: url)
        looper = AVPlayerLooper(player: player, templateItem: item)

        await waitUntilReady()
    }

    private func waitUntilReady() async {
        await withCheckedContinuation { (cont: CheckedContinuation<Void, Never>) in
            var resumed = false
            statusObserver = player.observe(
                \.currentItem?.status,
                options: [.initial, .new]
            ) { [weak self] player, _ in
                guard let self, !resumed else { return }
                switch player.currentItem?.status {
                case .readyToPlay:
                    resumed = true
                    self.statusObserver?.invalidate()
                    self.statusObserver = nil
                    Task { @MainActor [weak self] in
                        print("[VideoPlayer] Ready")
                        self?.isReady = true
                        // play() is intentionally NOT called here —
                        // isActive / onAppear / onChange decide whether to play
                    }
                    cont.resume()
                case .failed:
                    resumed = true
                    self.statusObserver?.invalidate()
                    self.statusObserver = nil
                    let msg = player.currentItem?.error?.localizedDescription ?? "unknown"
                    print("[VideoPlayer] Failed: \(msg)")
                    Task { @MainActor [weak self] in self?.isFailed = true }
                    cont.resume()
                default:
                    break
                }
            }
        }
    }

    func play()  { guard isReady else { return }; player.play()  }
    func pause() { player.pause() }
}

// MARK: - VideoLayerView
// iOS & iPadOS → UIViewRepresentable (layerClass promotion, no sublayer overhead)
// macOS        → NSViewRepresentable + AVPlayerLayer sublayer

#if canImport(UIKit)

struct VideoLayerView: UIViewRepresentable {
    let player: AVQueuePlayer
    func makeUIView(context: Context) -> PlayerUIView {
        let v = PlayerUIView()
        v.setPlayer(player)
        return v
    }
    func updateUIView(_ uiView: PlayerUIView, context: Context) {}
}

final class PlayerUIView: UIView {
    override class var layerClass: AnyClass { AVPlayerLayer.self }
    private var avLayer: AVPlayerLayer { layer as! AVPlayerLayer }
    func setPlayer(_ p: AVQueuePlayer) {
        avLayer.player       = p
        avLayer.videoGravity = .resizeAspectFill
    }
    override func layoutSubviews() {
        super.layoutSubviews()
        avLayer.frame = bounds
    }
}

#elseif canImport(AppKit)

struct VideoLayerView: NSViewRepresentable {
    let player: AVQueuePlayer
    func makeNSView(context: Context) -> PlayerNSView {
        let v = PlayerNSView()
        v.setPlayer(player)
        return v
    }
    func updateNSView(_ nsView: PlayerNSView, context: Context) {}
}

final class PlayerNSView: NSView {
    private let avLayer = AVPlayerLayer()
    override init(frame: NSRect) {
        super.init(frame: frame)
        wantsLayer = true
        avLayer.videoGravity = .resizeAspectFill
        layer?.addSublayer(avLayer)
    }
    required init?(coder: NSCoder) { fatalError() }
    func setPlayer(_ p: AVQueuePlayer) { avLayer.player = p }
    override func layout() {
        super.layout()
        avLayer.frame = bounds
    }
}

#endif

// MARK: - VideoThumbnailView

struct VideoThumbnailView: View {
    let thumbnailURL: String
    var body: some View {
        AsyncImage(url: URL(string: thumbnailURL)) { image in
            image.resizable().scaledToFill()
        } placeholder: {
            Rectangle().fill(Color.gray.opacity(0.4))
                .overlay(Image(systemName: "photo").foregroundColor(.white).font(.largeTitle))
        }
        .ignoresSafeArea()
        .clipped()
    }
}

// MARK: - RecipeExpansionOverlay — implement your own below
// struct RecipeExpansionOverlay: View { ... }

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
