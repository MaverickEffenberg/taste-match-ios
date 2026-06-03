import SwiftUI

// MARK: - Admin Dashboard
// Entry point for the Admin role. Only rendered in the tab bar when
// authVM.isAdmin is true. Provides links to the three management screens.
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
                        // Red badge showing count of items awaiting review
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
            // Success toast overlaid at the top (e.g. "Ingredient added")
            .overlay(alignment: .top) {
                if let msg = adminVM.successMessage {
                    ErrorToast(message: msg)
                }
            }
            // Pull-to-refresh reloads all three data sets in parallel
            .refreshable { await adminVM.loadAll() }
        }
    }
}

// MARK: - Ingredients Management
// Allows the admin to view, add, and soft-delete (deactivate) ingredients
// in the master_ingredients table that powers the search autocomplete.
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
                        // Visual indicator for deactivated ingredients
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
                // Swipe left to deactivate — soft delete keeps the row in DB
                // so existing recipes that reference the ingredient are unaffected.
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
            AddIngredientSheet(name: $newName, category: $newCategory) {
                Task {
                    await adminVM.addIngredient(
                        name: newName,
                        category: newCategory,
                        allergenTags: newAllergens
                    )
                    showAddSheet = false
                    newName = ""
                    newCategory = ""
                    newAllergens = []
                }
            }
        }
    }
}

struct AddIngredientSheet: View {
    @Binding var name: String
    @Binding var category: String
    let onSave: () -> Void

    // Local dismiss environment to close the sheet on Cancel
    @Environment(\.dismiss) private var dismiss

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
                    Button("Cancel") {
                        name = ""
                        category = ""
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Diet Tags Management
// Allows the admin to view active diet tags and add new ones.
// Inactive tags are hidden from user-facing diet preference toggles.
struct DietTagsManagementView: View {
    @ObservedObject var adminVM: AdminViewModel

    @State private var showAddSheet = false
    @State private var newTagName = ""
    @State private var newTagIcon = ""

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
            // Swipe to deactivate a diet tag
            .swipeActions {
                Button(role: .destructive) {
                    Task { await adminVM.deactivateDietTag(tag) }
                } label: {
                    Label("Deactivate", systemImage: "eye.slash")
                }
            }
        }
        .navigationTitle("Diet Tags")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button(action: { showAddSheet = true }) {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(isPresented: $showAddSheet) {
            AddDietTagSheet(name: $newTagName, iconName: $newTagIcon) {
                Task {
                    await adminVM.addDietTag(name: newTagName, iconName: newTagIcon)
                    showAddSheet = false
                    newTagName = ""
                    newTagIcon = ""
                }
            }
        }
    }
}

// Sheet for creating a new diet tag with a name and SF Symbol icon name
struct AddDietTagSheet: View {
    @Binding var name: String
    @Binding var iconName: String
    let onSave: () -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                TextField("Tag name (e.g. Kosher)", text: $name)
                TextField("SF Symbol name (e.g. star.fill)", text: $iconName)
                // Live preview of the chosen SF Symbol
                if !iconName.isEmpty {
                    HStack {
                        Text("Preview:")
                        Image(systemName: iconName)
                            .foregroundColor(.accentColor)
                    }
                }
            }
            .navigationTitle("New Diet Tag")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: onSave).disabled(name.isEmpty || iconName.isEmpty)
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        name = ""
                        iconName = ""
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Content Moderation
// Shows all submissions with "pending" status. The admin can approve
// (publishes the recipe to the feed) or reject (hides it with an optional note).
struct ContentModerationView: View {
    @ObservedObject var adminVM: AdminViewModel

    // Rejection note typed by the admin before rejecting a submission
    @State private var rejectionNotes: [UUID: String] = [:]

    var body: some View {
        List(adminVM.pendingContent) { content in
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    // Colour-coded status dot: orange = pending, green = approved, red = rejected
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
                    // Optional rejection note field, shown per-row
                    TextField("Rejection note (optional)", text: Binding(
                        get: { rejectionNotes[content.id] ?? "" },
                        set: { rejectionNotes[content.id] = $0 }
                    ))
                    .font(.caption)
                    .textFieldStyle(.roundedBorder)

                    HStack(spacing: 12) {
                        Button("Approve") {
                            Task { await adminVM.approveContent(content) }
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.green)

                        Button("Reject") {
                            let note = rejectionNotes[content.id] ?? ""
                            Task { await adminVM.rejectContent(content, note: note) }
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
