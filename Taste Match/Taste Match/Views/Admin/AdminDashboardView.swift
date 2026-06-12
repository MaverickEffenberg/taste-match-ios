import SwiftUI

struct AdminDashboardView: View {
    @ObservedObject var adminVM: AdminViewModel

    var body: some View {
        NavigationStack {
            Group {
                if adminVM.isLoading {
                    ProgressView("Loading Recipes…")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if adminVM.allRecipes.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "tray")
                            .font(.system(size: 50))
                            .foregroundColor(.secondary)
                        Text("Tidak ada konten")
                            .font(.title3).bold()
                    }
                } else {
                    List {
                        ForEach(adminVM.allRecipes) { recipe in
                            HStack(spacing: 12) {
                                AsyncImage(url: URL(string: recipe.thumbnailURL)) { img in
                                    img.resizable().scaledToFill()
                                } placeholder: {
                                    Rectangle().fill(Color.secondary.opacity(0.2))
                                }
                                .frame(width: 60, height: 60)
                                .cornerRadius(8)
                                .clipped()

                                VStack(spacing: 4) {
                                    Text(recipe.title)
                                        .font(.headline)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .lineLimit(1)

                                    Text("@\(recipe.creatorUsername)")
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                }

                                Spacer()
                                
                                Button(role: .destructive) {
                                    Task { await adminVM.deleteRecipe(recipe) }
                                } label: {
                                    Image(systemName: "trash")
                                        .foregroundColor(.red)
                                }
                                .buttonStyle(.plain)
                            }
                            .padding(.vertical, 4)
                            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                Button(role: .destructive) {
                                    Task { await adminVM.deleteRecipe(recipe) }
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                        }
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("Admin Dashboard")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        Task { await adminVM.loadAllRecipes() }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                }
            }
            .overlay(alignment: .top) {
                VStack {
                    if let errorMsg = adminVM.errorMessage {
                        ErrorToast(message: errorMsg)
                            .transition(.move(edge: .top).combined(with: .opacity))
                            .onAppear { autoDismissError() }
                    }
                    if let successMsg = adminVM.successMessage {
                        SuccessToast(message: successMsg)
                            .transition(.move(edge: .top).combined(with: .opacity))
                            .onAppear { autoDismissSuccess() }
                    }
                }
                .animation(.spring(), value: adminVM.errorMessage)
                .animation(.spring(), value: adminVM.successMessage)
            }
            .refreshable { await adminVM.loadAllRecipes() }
        }
    }

    private func autoDismissError() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
            adminVM.errorMessage = nil
        }
    }

    private func autoDismissSuccess() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
            adminVM.successMessage = nil
        }
    }
}

struct SuccessToast: View {
    let message: String
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "checkmark.circle.fill")
            Text(message)
        }
        .font(.caption).bold()
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Color.green.opacity(0.9))
        .foregroundColor(.white)
        .clipShape(Capsule())
        .shadow(radius: 5)
        .padding(.top, 10)
    }
}
