import Foundation
import Combine
import PhotosUI
import SwiftUI

// MARK: - Upload Phase

enum UploadPhase: Equatable {
    case idle
    case uploadingVideo
    case uploadingThumbnail
    case savingRecipe
    case done(Recipe)
    case failed(String)
}

// MARK: - CreatorViewModel

@MainActor
final class CreatorViewModel: ObservableObject {

    // MARK: Form state
    @Published var draft = RecipeDraft()

    // MARK: Media picks
    @Published var selectedVideoItem: PhotosPickerItem?
    @Published var selectedThumbnailItem: PhotosPickerItem?
    @Published var videoData: Data?
    @Published var thumbnailData: Data?
    @Published var thumbnailImage: Image?

    // MARK: Upload state
    @Published var uploadPhase: UploadPhase = .idle
    @Published var uploadProgress: Double = 0.0   // 0.0 – 1.0 cosmetic progress
    @Published var errorMessage: String?

    // MARK: Past submissions
    @Published var submissions: [CreatorSubmission] = []
    @Published var isLoadingSubmissions: Bool = false

    private let uploadService: CreatorUploadServiceProtocol
    private var progressTimer: Timer?

    // MARK: - Init

    init(uploadService: CreatorUploadServiceProtocol = SupabaseCreatorUploadService()) {
        self.uploadService = uploadService
    }

    // MARK: - Media Loading

    func loadVideoData() async {
        guard let item = selectedVideoItem else { return }
        do {
            videoData = try await item.loadTransferable(type: Data.self)
        } catch {
            errorMessage = "Could not load video: \(error.localizedDescription)"
        }
    }

    func loadThumbnailData() async {
        guard let item = selectedThumbnailItem else { return }
        do {
            if let data = try await item.loadTransferable(type: Data.self) {
                thumbnailData = data
                if let uiImage = platformImage(from: data) {
                    thumbnailImage = Image(platformImageName: uiImage)
                }
            }
        } catch {
            errorMessage = "Could not load thumbnail: \(error.localizedDescription)"
        }
    }

    // MARK: - Validation

    var canSubmit: Bool {
        videoData != nil &&
        thumbnailData != nil &&
        !draft.title.trimmingCharacters(in: .whitespaces).isEmpty &&
        !draft.description.trimmingCharacters(in: .whitespaces).isEmpty &&
        !draft.ingredients.isEmpty &&
        !draft.steps.isEmpty
    }

    // MARK: - Submit

    func submitRecipe() async {
        guard canSubmit,
              let videoData,
              let thumbnailData else { return }

        errorMessage = nil
        uploadProgress = 0.0
        startProgressAnimation()

        do {
            uploadPhase = .uploadingVideo
            let videoURL = try await uploadService.uploadVideo(
                videoData,
                filename: "recipe_\(UUID().uuidString).mp4"
            )
            uploadProgress = 0.45

            uploadPhase = .uploadingThumbnail
            let thumbnailURL = try await uploadService.uploadThumbnail(
                thumbnailData,
                filename: "thumb_\(UUID().uuidString).jpg"
            )
            uploadProgress = 0.75

            uploadPhase = .savingRecipe
            let recipe = try await uploadService.submitRecipe(
                draft,
                videoURL: videoURL,
                thumbnailURL: thumbnailURL
            )
            uploadProgress = 1.0
            stopProgressAnimation()
            uploadPhase = .done(recipe)
            resetForm()
        } catch {
            stopProgressAnimation()
            uploadPhase = .failed(error.localizedDescription)
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Submissions

    func loadMySubmissions() async {
        isLoadingSubmissions = true
        do {
            submissions = try await uploadService.fetchMySubmissions()
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoadingSubmissions = false
    }

    // MARK: - Helpers

    func resetForm() {
        draft = RecipeDraft()
        selectedVideoItem = nil
        selectedThumbnailItem = nil
        videoData = nil
        thumbnailData = nil
        thumbnailImage = nil
    }

    func resetUploadState() {
        uploadPhase = .idle
        uploadProgress = 0
        errorMessage = nil
    }

    // Cosmetic pulsed-progress animation while network I/O runs
    private func startProgressAnimation() {
        progressTimer = Timer.scheduledTimer(withTimeInterval: 0.3, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self, self.uploadProgress < 0.9 else { return }
                self.uploadProgress = min(self.uploadProgress + 0.02, 0.9)
            }
        }
    }

    private func stopProgressAnimation() {
        progressTimer?.invalidate()
        progressTimer = nil
    }
}

// MARK: - Cross-platform image helper

#if os(iOS)
import UIKit
private func platformImage(from data: Data) -> UIImage? { UIImage(data: data) }
extension Image {
    init(platformImageName image: UIImage) { self.init(uiImage: image) }
}
#elseif os(macOS)
import AppKit
private func platformImage(from data: Data) -> NSImage? { NSImage(data: data) }
extension Image {
    init(platformImageName image: NSImage) { self.init(nsImage: image) }
}
#endif
