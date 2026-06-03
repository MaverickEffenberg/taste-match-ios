import SwiftUI
import PhotosUI

// MARK: - Step Enum

enum CreateRecipeStep: Int, CaseIterable {
    case video       = 0
    case details     = 1
    case ingredients = 2
    case steps       = 3
    case review      = 4

    var title: String {
        switch self {
        case .video:       return "Video"
        case .details:     return "Details"
        case .ingredients: return "Ingredients"
        case .steps:       return "Steps"
        case .review:      return "Review"
        }
    }

    var systemImage: String {
        switch self {
        case .video:       return "video.badge.plus"
        case .details:     return "doc.text"
        case .ingredients: return "cart"
        case .steps:       return "list.number"
        case .review:      return "checkmark.seal"
        }
    }
}

// MARK: - CreateRecipeView

struct CreateRecipeView: View {
    @StateObject private var creatorVM = CreatorViewModel()
    @State private var currentStep: CreateRecipeStep = .video
    @State private var showSuccessBanner = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                StepProgressBar(current: currentStep)
                    .padding(.horizontal)
                    .padding(.top, 8)

                Divider().padding(.top, 8)

                Group {
                    switch currentStep {
                    case .video:       StepVideoPickerView(creatorVM: creatorVM)
                    case .details:     StepDetailsView(draft: $creatorVM.draft)
                    case .ingredients: StepIngredientsView(draft: $creatorVM.draft)
                    case .steps:       StepStepsView(draft: $creatorVM.draft)
                    case .review:      StepReviewView(creatorVM: creatorVM)
                    }
                }
                .padding()
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)

                Divider()
                StepNavBar(
                    step: currentStep,
                    canAdvance: canAdvance,
                    canSubmit: creatorVM.canSubmit,
                    onBack: goBack,
                    onNext: goNext,
                    onSubmit: { Task { await creatorVM.submitRecipe() } }
                )
                .padding()
            }
            .navigationTitle("New Recipe")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .overlay {
                switch creatorVM.uploadPhase {
                case .uploadingVideo, .uploadingThumbnail, .savingRecipe:
                    UploadProgressOverlay(creatorVM: creatorVM)
                default:
                    EmptyView()
                }
            }
            .onChange(of: creatorVM.uploadPhase) { _, phase in
                if case .done = phase {
                    showSuccessBanner = true
                    currentStep = .video
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                        showSuccessBanner = false
                        creatorVM.resetUploadState()
                    }
                }
            }
            .overlay(alignment: .top) {
                if showSuccessBanner {
                    SuccessBanner()
                        .transition(.move(edge: .top).combined(with: .opacity))
                        .animation(.spring(), value: showSuccessBanner)
                        .padding(.top, 8)
                }
            }
        }
    }

    private var canAdvance: Bool {
        switch currentStep {
        case .video:       return creatorVM.videoData != nil && creatorVM.thumbnailData != nil
        case .details:     return !creatorVM.draft.title.isEmpty && !creatorVM.draft.description.isEmpty
        case .ingredients: return !creatorVM.draft.ingredients.isEmpty
        case .steps:       return !creatorVM.draft.steps.isEmpty
        case .review:      return false
        }
    }

    private func goNext() {
        if let step = CreateRecipeStep(rawValue: currentStep.rawValue + 1) {
            withAnimation(.easeInOut) { currentStep = step }
        }
    }

    private func goBack() {
        if let step = CreateRecipeStep(rawValue: currentStep.rawValue - 1) {
            withAnimation(.easeInOut) { currentStep = step }
        }
    }
}

// MARK: - Step 1: Video Picker

private struct StepVideoPickerView: View {
    @ObservedObject var creatorVM: CreatorViewModel

    var body: some View {
        VStack(spacing: 20) {
            PhotosPicker(
                selection: $creatorVM.selectedThumbnailItem,
                matching: .images,
                photoLibrary: .shared()
            ) {
                ThumbnailPickerPreview(image: creatorVM.thumbnailImage)
            }
            .onChange(of: creatorVM.selectedThumbnailItem) { _, _ in
                Task { await creatorVM.loadThumbnailData() }
            }

            PhotosPicker(
                selection: $creatorVM.selectedVideoItem,
                matching: .videos,
                photoLibrary: .shared()
            ) {
                Label(
                    creatorVM.videoData != nil ? "Video Selected ✓" : "Choose Recipe Video",
                    systemImage: creatorVM.videoData != nil ? "checkmark.circle.fill" : "video.badge.plus"
                )
                .frame(maxWidth: .infinity)
                .padding()
                .background(creatorVM.videoData != nil ? Color.green.opacity(0.15) : Color.accentColor.opacity(0.1))
                .foregroundColor(creatorVM.videoData != nil ? .green : .accentColor)
                .cornerRadius(12)
            }
            .onChange(of: creatorVM.selectedVideoItem) { _, _ in
                Task { await creatorVM.loadVideoData() }
            }

            Text("Tip: Pick a short portrait video (under 60s) for the best viewing experience.")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
    }
}

private struct ThumbnailPickerPreview: View {
    let image: Image?

    var body: some View {
        ZStack {
            if let image {
                image.resizable().scaledToFill()
            } else {
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.secondary.opacity(0.15))
                VStack(spacing: 8) {
                    Image(systemName: "photo.on.rectangle.angled")
                        .font(.system(size: 40))
                        .foregroundColor(.secondary)
                    Text("Tap to pick thumbnail")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }
        }
        .frame(maxWidth: .infinity, minHeight: 200, maxHeight: 220)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.secondary.opacity(0.3)))
    }
}

// MARK: - Step 2: Details

private struct StepDetailsView: View {
    @Binding var draft: RecipeDraft

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                FormLabel("Title")
                TextField("e.g. Spicy Thai Basil Chicken", text: $draft.title)
                    .textFieldStyle(.roundedBorder)

                FormLabel("Description")
                TextEditor(text: $draft.description)
                    .frame(minHeight: 80)
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.secondary.opacity(0.3)))

                FormLabel("Diet Tags")
                MultiToggleGrid(options: DietTag.allCases.map(\.rawValue), selected: $draft.dietTags)

                FormLabel("Allergen Tags")
                MultiToggleGrid(options: AllergenTag.allCases.map(\.rawValue), selected: $draft.allergenTags)
            }
        }
    }
}

// MARK: - Step 3: Ingredients
// FIX: Removed `.environment(\.editMode, .constant(.active))` — editMode is
// iOS-only. Replaced with manual delete/move buttons that compile on macOS.

private struct StepIngredientsView: View {
    @Binding var draft: RecipeDraft
    @State private var newIngredient = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                TextField("Add ingredient", text: $newIngredient)
                    .textFieldStyle(.roundedBorder)
                    #if os(iOS)
                    .autocorrectionDisabled()
                    #endif
                Button {
                    let clean = newIngredient.trimmingCharacters(in: .whitespaces).lowercased()
                    guard !clean.isEmpty else { return }
                    draft.ingredients.append(clean)
                    newIngredient = ""
                } label: {
                    Image(systemName: "plus.circle.fill").font(.title2)
                }
                .disabled(newIngredient.trimmingCharacters(in: .whitespaces).isEmpty)
            }

            if draft.ingredients.isEmpty {
                Text("No ingredients added yet.")
                    .foregroundColor(.secondary)
                    .font(.callout)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.top, 20)
            } else {
                // Cross-platform editable list (no editMode dependency)
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(Array(draft.ingredients.enumerated()), id: \.element) { index, ingredient in
                            HStack {
                                Image(systemName: "line.3.horizontal")
                                    .foregroundColor(.secondary)
                                    .font(.callout)
                                Text(ingredient.capitalized)
                                    .font(.body)
                                Spacer()
                                Button {
                                    draft.ingredients.remove(at: index)
                                } label: {
                                    Image(systemName: "minus.circle.fill")
                                        .foregroundColor(.red)
                                }
                                .buttonStyle(.plain)
                            }
                            .padding(.vertical, 8)
                            .padding(.horizontal, 4)
                            Divider()
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Step 4: Steps
// FIX: Same editMode removal. Cross-platform manual delete with renumbering.

private struct StepStepsView: View {
    @Binding var draft: RecipeDraft
    @State private var newInstruction = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 8) {
                TextEditor(text: $newInstruction)
                    .frame(minHeight: 60, maxHeight: 100)
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.secondary.opacity(0.3)))
                Button {
                    let clean = newInstruction.trimmingCharacters(in: .whitespaces)
                    guard !clean.isEmpty else { return }
                    draft.steps.append(RecipeStep(
                        stepNumber: draft.steps.count + 1,
                        instruction: clean
                    ))
                    newInstruction = ""
                } label: {
                    Image(systemName: "plus.circle.fill").font(.title2)
                }
                .disabled(newInstruction.trimmingCharacters(in: .whitespaces).isEmpty)
            }

            if draft.steps.isEmpty {
                Text("No steps added yet.")
                    .foregroundColor(.secondary)
                    .font(.callout)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.top, 20)
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(Array(draft.steps.enumerated()), id: \.element.id) { index, step in
                            HStack(alignment: .top, spacing: 10) {
                                Text("\(step.stepNumber).")
                                    .font(.headline)
                                    .foregroundColor(.accentColor)
                                    .frame(width: 28, alignment: .leading)
                                Text(step.instruction)
                                    .font(.body)
                                Spacer()
                                Button {
                                    draft.steps.remove(at: index)
                                    // Renumber remaining
                                    for i in draft.steps.indices {
                                        draft.steps[i].stepNumber = i + 1
                                    }
                                } label: {
                                    Image(systemName: "minus.circle.fill")
                                        .foregroundColor(.red)
                                }
                                .buttonStyle(.plain)
                            }
                            .padding(.vertical, 8)
                            .padding(.horizontal, 4)
                            Divider()
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Step 5: Review

private struct StepReviewView: View {
    @ObservedObject var creatorVM: CreatorViewModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if let thumbnail = creatorVM.thumbnailImage {
                    thumbnail
                        .resizable()
                        .scaledToFill()
                        .frame(maxWidth: .infinity, maxHeight: 180)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                ReviewSection(title: "Title")        { Text(creatorVM.draft.title).font(.headline) }
                ReviewSection(title: "Description")  { Text(creatorVM.draft.description).font(.body).foregroundColor(.secondary) }
                ReviewSection(title: "Diet Tags")     { TagRow(tags: creatorVM.draft.dietTags) }
                ReviewSection(title: "Allergens")     { TagRow(tags: creatorVM.draft.allergenTags) }
                ReviewSection(title: "Ingredients (\(creatorVM.draft.ingredients.count))") {
                    ForEach(creatorVM.draft.ingredients, id: \.self) {
                        Text("• \($0.capitalized)").font(.callout)
                    }
                }
                ReviewSection(title: "Steps (\(creatorVM.draft.steps.count))") {
                    ForEach(creatorVM.draft.steps) { step in
                        Text("\(step.stepNumber). \(step.instruction)").font(.callout)
                    }
                }

                if let err = creatorVM.errorMessage {
                    Label(err, systemImage: "exclamationmark.triangle.fill")
                        .font(.caption)
                        .foregroundColor(.red)
                        .padding(.top, 4)
                }
            }
        }
    }
}

// MARK: - Shared Sub-views

private struct FormLabel: View {
    let text: String
    init(_ text: String) { self.text = text }
    var body: some View {
        Text(text).font(.subheadline).bold().foregroundColor(.secondary)
    }
}

private struct MultiToggleGrid: View {
    let options: [String]
    @Binding var selected: [String]

    var body: some View {
        LazyVGrid(
            columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())],
            spacing: 8
        ) {
            ForEach(options, id: \.self) { option in
                let isOn = selected.contains(option)
                Button {
                    if isOn { selected.removeAll { $0 == option } }
                    else     { selected.append(option) }
                } label: {
                    Text(option)
                        .font(.caption).bold()
                        .padding(.horizontal, 10).padding(.vertical, 6)
                        .frame(maxWidth: .infinity)
                        .background(isOn ? Color.accentColor : Color.secondary.opacity(0.15))
                        .foregroundColor(isOn ? .white : .primary)
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }
        }
    }
}

private struct ReviewSection<Content: View>: View {
    let title: String
    @ViewBuilder let content: () -> Content
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption).bold().foregroundColor(.secondary).textCase(.uppercase)
            content()
        }
        .padding(.vertical, 4)
    }
}

private struct TagRow: View {
    let tags: [String]
    var body: some View {
        if tags.isEmpty {
            Text("None").foregroundColor(.secondary).font(.callout)
        } else {
            HStack(spacing: 6) { ForEach(tags, id: \.self) { DietTagBadge(tag: $0) } }
        }
    }
}

// MARK: - Progress Bar

private struct StepProgressBar: View {
    let current: CreateRecipeStep

    var body: some View {
        HStack(spacing: 0) {
            ForEach(CreateRecipeStep.allCases, id: \.rawValue) { step in
                VStack(spacing: 4) {
                    ZStack {
                        Circle()
                            .fill(step.rawValue <= current.rawValue
                                  ? Color.accentColor
                                  : Color.secondary.opacity(0.2))
                            .frame(width: 28, height: 28)
                        Image(systemName: step.systemImage)
                            .font(.caption2)
                            .foregroundColor(step.rawValue <= current.rawValue ? .white : .secondary)
                    }
                    Text(step.title)
                        .font(.system(size: 9, weight: .medium))
                        .foregroundColor(step == current ? .accentColor : .secondary)
                }
                if step != CreateRecipeStep.allCases.last {
                    Rectangle()
                        .fill(step.rawValue < current.rawValue
                              ? Color.accentColor
                              : Color.secondary.opacity(0.2))
                        .frame(height: 2)
                        .frame(maxWidth: .infinity)
                        .padding(.bottom, 16)
                }
            }
        }
    }
}

// MARK: - Nav Bar

private struct StepNavBar: View {
    let step: CreateRecipeStep
    let canAdvance: Bool
    let canSubmit: Bool
    let onBack: () -> Void
    let onNext: () -> Void
    let onSubmit: () -> Void

    var body: some View {
        HStack {
            if step != .video {
                Button(action: onBack) { Label("Back", systemImage: "chevron.left") }
                    .buttonStyle(.bordered)
            }
            Spacer()
            if step == .review {
                Button(action: onSubmit) {
                    Label("Submit for Review", systemImage: "paperplane.fill")
                }
                .buttonStyle(.borderedProminent)
                .disabled(!canSubmit)
            } else {
                Button(action: onNext) { Label("Next", systemImage: "chevron.right") }
                    .buttonStyle(.borderedProminent)
                    .disabled(!canAdvance)
            }
        }
    }
}

// MARK: - Upload Overlay

private struct UploadProgressOverlay: View {
    @ObservedObject var creatorVM: CreatorViewModel

    var phaseLabel: String {
        switch creatorVM.uploadPhase {
        case .uploadingVideo:      return "Uploading video…"
        case .uploadingThumbnail:  return "Uploading thumbnail…"
        case .savingRecipe:        return "Saving recipe…"
        default:                   return "Working…"
        }
    }

    var body: some View {
        ZStack {
            Color.black.opacity(0.55).ignoresSafeArea()
            VStack(spacing: 16) {
                ProgressView(value: creatorVM.uploadProgress)
                    .progressViewStyle(.linear)
                    .tint(.accentColor)
                    .frame(width: 240)
                Text(phaseLabel)
                    .font(.subheadline).bold()
                    .foregroundColor(.white)
            }
            .padding(28)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 20))
        }
    }
}

private struct SuccessBanner: View {
    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "checkmark.seal.fill").foregroundColor(.green)
            Text("Recipe submitted for review!")
                .font(.subheadline).bold()
        }
        .padding(.horizontal, 20).padding(.vertical, 10)
        .background(.regularMaterial, in: Capsule())
        .shadow(radius: 6)
    }
}
