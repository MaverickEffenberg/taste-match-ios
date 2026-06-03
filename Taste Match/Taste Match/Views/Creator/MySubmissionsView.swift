import SwiftUI

struct MySubmissionsView: View {
    @StateObject private var creatorVM = CreatorViewModel()

    var body: some View {
        NavigationStack {
            Group {
                if creatorVM.isLoadingSubmissions {
                    ProgressView("Loading submissions…")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)

                } else if creatorVM.submissions.isEmpty {
                    EmptySubmissionsView()

                } else {
                    List(creatorVM.submissions) { submission in
                        SubmissionRow(submission: submission)
                    }
                    #if os(iOS)
                    .listStyle(.insetGrouped)
                    #else
                    .listStyle(.inset)
                    #endif
                }
            }
            .navigationTitle("My Submissions")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        Task { await creatorVM.loadMySubmissions() }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                }
            }
            .task {
                await creatorVM.loadMySubmissions()
            }
            .overlay(alignment: .top) {
                if let err = creatorVM.errorMessage {
                    ErrorToast(message: err)
                        .transition(.slide)
                        .padding(.top, 8)
                }
            }
        }
    }
}

// MARK: - Submission Row

private struct SubmissionRow: View {
    let submission: CreatorSubmission

    var body: some View {
        HStack(spacing: 12) {
            AsyncImage(url: URL(string: submission.recipe.thumbnailURL)) { img in
                img.resizable().scaledToFill()
            } placeholder: {
                Rectangle().fill(Color.secondary.opacity(0.2))
                    .overlay(Image(systemName: "photo").foregroundColor(.secondary))
            }
            .frame(width: 70, height: 70)
            .cornerRadius(8)
            .clipped()

            VStack(alignment: .leading, spacing: 4) {
                Text(submission.recipe.title)
                    .font(.headline)
                    .lineLimit(1)

                HStack(spacing: 6) {
                    StatusBadge(status: submission.status)
                    Text(submission.submittedAt.formatted(date: .abbreviated, time: .omitted))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                if !submission.moderatorNote.isEmpty {
                    Text("Note: \(submission.moderatorNote)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Status Badge

struct StatusBadge: View {
    let status: String

    var badgeColor: Color {
        switch status.lowercased() {
        case "approved": return .green
        case "rejected": return .red
        default:         return .orange    // "pending"
        }
    }

    var badgeIcon: String {
        switch status.lowercased() {
        case "approved": return "checkmark.seal.fill"
        case "rejected": return "xmark.octagon.fill"
        default:         return "clock.fill"
        }
    }

    var body: some View {
        Label(status.capitalized, systemImage: badgeIcon)
            .font(.caption2).bold()
            .padding(.horizontal, 8).padding(.vertical, 3)
            .background(badgeColor.opacity(0.15))
            .foregroundColor(badgeColor)
            .clipShape(Capsule())
    }
}

// MARK: - Empty State

private struct EmptySubmissionsView: View {
    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: "tray")
                .font(.system(size: 50))
                .foregroundColor(.secondary)
            Text("No submissions yet")
                .font(.title3).bold()
            Text("Use the Create tab to upload your first recipe.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
    }
}
