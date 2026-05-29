
import SwiftUI

struct AdminDashboardView: View {
    @ObservedObject var adminVM: AdminViewModel

    var body: some View {
        NavigationStack {
            List {
                NavigationLink("Ingredients (\(adminVM.masterIngredients.count))") {
                    IngredientsManagementView(adminVM: adminVM)
                }

                NavigationLink("Diet Tags (\(adminVM.masterDietTags.count))") {
                    DietTagsManagementView(adminVM: adminVM)
                }

                NavigationLink {
                    ContentModerationView(adminVM: adminVM)
                } label: {
                    HStack {
                        Text("Content Moderation")
                        Spacer()
                        let pendingCount = adminVM.pendingContent.filter { $0.status == "pending" }.count
                        if pendingCount > 0 {
                            Text("\(pendingCount)")
                                .font(.caption2)
                                .padding(5)
                                .background(Color.red)
                                .foregroundColor(.white)
                                .clipShape(Circle())
                        }
                    }
                }
            }
            .navigationTitle("Admin Dashboard")
            .overlay(alignment: .top) {
                if let msg = adminVM.successMessage {
                    ErrorToast(message: msg)
                }
            }
            .refreshable { await adminVM.loadAll() }
        }
    }
}

struct IngredientsManagementView: View {
    @ObservedObject var adminVM: AdminViewModel

    @State private var showAddSheet = false
    @State private var newName = ""
    @State private var newCategory = ""
    @State private var newAllergens: [String] = []

    var body: some View {
        List {
            ForEach(adminVM.masterIngredients) { ingredient in
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(ingredient.name).font(.headline)
                        Spacer()
                        if !ingredient.isActive {
                            Text("Inactive")
                                .font(.caption2)
                                .padding(4)
                                .background(Color.gray)
                                .foregroundColor(.white)
                                .cornerRadius(4)
                        }
                    }
                    Text(ingredient.category)
                        .font(.subheadline).foregroundColor(.secondary)
                    if !ingredient.allergenTags.isEmpty {
                        Text("Allergens: \(ingredient.allergenTags.joined(separator: ", "))")
                            .font(.caption).foregroundColor(.orange)
                    }
                }
                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                    Button(role: .destructive) {
                        Task { await adminVM.deactivateIngredient(ingredient) }
                    } label: {
                        Label("Deactivate", systemImage: "eye.slash")
                    }
                }
            }
        }
        .navigationTitle("Ingredients")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button(action: { showAddSheet = true }) {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(isPresented: $showAddSheet) {
            AddIngredientSheet(
                name: $newName,
                category: $newCategory
            ) {
                Task {
                    await adminVM.addIngredient(name: newName, category: newCategory, allergenTags: newAllergens)
                    showAddSheet = false
                    newName = ""; newCategory = ""; newAllergens = []
                }
            }
        }
    }
}

struct AddIngredientSheet: View {
    @Binding var name: String
    @Binding var category: String
    let onSave: () -> Void

    var body: some View {
        NavigationStack {
            Form {
                TextField("Ingredient name", text: $name)
                TextField("Category (e.g. Protein)", text: $category)
            }
            .navigationTitle("New Ingredient")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: onSave).disabled(name.isEmpty)
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { name = ""; category = "" }
                }
            }
        }
    }
}

struct DietTagsManagementView: View {
    @ObservedObject var adminVM: AdminViewModel

    var body: some View {
        List(adminVM.masterDietTags) { tag in
            HStack {
                Image(systemName: tag.iconName)
                    .foregroundColor(.accentColor)
                Text(tag.name)
                Spacer()
                if !tag.isActive {
                    Text("Inactive").font(.caption2).foregroundColor(.secondary)
                }
            }
            .swipeActions {
                Button(role: .destructive) {
                    Task { await adminVM.deactivateDietTag(tag) }
                } label: {
                    Label("Deactivate", systemImage: "eye.slash")
                }
            }
        }
        .navigationTitle("Diet Tags")
    }
}

struct ContentModerationView: View {
    @ObservedObject var adminVM: AdminViewModel
    @State private var rejectionNote = ""

    var body: some View {
        List(adminVM.pendingContent) { content in
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Circle()
                        .fill(statusColor(content.status))
                        .frame(width: 10, height: 10)
                    Text("Recipe ID: \(content.recipeID.uuidString.prefix(8))…")
                        .font(.subheadline)
                    Spacer()
                    Text(content.status.capitalized)
                        .font(.caption).foregroundColor(.secondary)
                }

                if content.status == "pending" {
                    HStack(spacing: 12) {
                        Button("Approve") {
                            Task { await adminVM.approveContent(content) }
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.green)

                        Button("Reject") {
                            Task { await adminVM.rejectContent(content, note: rejectionNote) }
                        }
                        .buttonStyle(.bordered)
                        .tint(.red)
                    }
                }
            }
            .padding(.vertical, 4)
        }
        .navigationTitle("Content Moderation")
    }

    private func statusColor(_ status: String) -> Color {
        switch status {
        case "approved": return .green
        case "rejected": return .red
        default:         return .orange
        }
    }
}
