import SwiftUI

struct ContentView: View {
    @EnvironmentObject var authVM: AuthViewModel
    @EnvironmentObject var profileVM: ProfileViewModel

    var body: some View {
        Group {
            if authVM.currentUser == nil {
                LoginView()
                    .environmentObject(authVM)
            } else {
                MainTabView()
                    .environmentObject(authVM)
                    .environmentObject(profileVM)
            }
        }
    }
}

struct MainTabView: View {
    @EnvironmentObject var authVM: AuthViewModel
    @EnvironmentObject var profileVM: ProfileViewModel

    @StateObject private var feedVM: FeedViewModel
    @StateObject private var searchVM: SearchViewModel
    @StateObject private var adminVM: AdminViewModel

    init() {
        let pvm = ProfileViewModel()
        _feedVM   = StateObject(wrappedValue: FeedViewModel(profileViewModel: pvm))
        _searchVM = StateObject(wrappedValue: SearchViewModel(profileViewModel: pvm))
        _adminVM  = StateObject(wrappedValue: AdminViewModel())
    }

    var body: some View {
        TabView {
            // MARK: Discover
            FeedView(viewModel: feedVM, profileVM: profileVM)
                .tabItem { Label("Discover", systemImage: "play.tv") }

            // MARK: Search
            SearchView(viewModel: searchVM, profileVM: profileVM)
                .tabItem { Label("Search", systemImage: "magnifyingglass") }

            // MARK: Create  ← new tab visible to all logged-in users
            CreateRecipeTabView()
                .tabItem { Label("Create", systemImage: "plus.circle.fill") }

            // MARK: Saved
            PlaylistView(profileVM: profileVM)
                .tabItem { Label("Saved", systemImage: "bookmark") }

            // MARK: Profile
            ProfileView(profileVM: profileVM, authVM: authVM)
                .tabItem { Label("Profile", systemImage: "person.crop.circle") }

            // MARK: Admin (role-gated)
            if authVM.isAdmin {
                AdminDashboardView(adminVM: adminVM)
                    .tabItem { Label("Admin", systemImage: "shield.checkered") }
            }
        }
        #if os(macOS)
        .frame(minWidth: 900, minHeight: 600)
        #endif
    }
}

// MARK: - Create Tab Container
// Hosts both CreateRecipeView and MySubmissionsView in a NavigationSplitView
// on macOS (sidebar + detail) or as a segmented NavigationStack on iOS.

struct CreateRecipeTabView: View {
    @StateObject private var creatorVM = CreatorViewModel()

    #if os(iOS)
    @State private var selectedSegment = 0
    #endif

    var body: some View {
        #if os(iOS)
        NavigationStack {
            Group {
                switch selectedSegment {
                case 0:  CreateRecipeView()
                default: MySubmissionsView()
                }
            }
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Picker("", selection: $selectedSegment) {
                        Text("New Recipe").tag(0)
                        Text("My Submissions").tag(1)
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 260)
                }
            }
        }
        #else
        NavigationSplitView {
            List {
                NavigationLink("New Recipe",    destination: CreateRecipeView())
                NavigationLink("My Submissions", destination: MySubmissionsView())
            }
            .navigationTitle("Create")
        } detail: {
            CreateRecipeView()
        }
        #endif
    }
}

// MARK: - LoginView (unchanged)

struct LoginView: View {
    @EnvironmentObject var authVM: AuthViewModel

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            VStack(spacing: 8) {
                Image(systemName: "fork.knife.circle.fill")
                    .font(.system(size: 80))
                    .foregroundStyle(.orange, .green)
                Text("FridgeFlix")
                    .font(.largeTitle).bold()
                Text("Cook what you have. Waste nothing.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }

            Spacer()

            Button(action: { Task { await authVM.signInWithGoogle() } }) {
                HStack {
                    Image(systemName: "globe")
                    Text("Sign in with Google")
                        .bold()
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(.background)
                .foregroundColor(.primary)
                .cornerRadius(12)
                .shadow(radius: 4)
                .padding(.horizontal, 32)
            }
            .disabled(authVM.isLoading)
            .overlay {
                if authVM.isLoading { ProgressView() }
            }

            if let err = authVM.errorMessage {
                Text(err)
                    .font(.caption)
                    .foregroundColor(.red)
                    .padding(.horizontal)
            }

            Spacer()
        }
        .background(
            LinearGradient(colors: [.orange.opacity(0.15), .green.opacity(0.1)],
                           startPoint: .topLeading, endPoint: .bottomTrailing)
                .ignoresSafeArea()
        )
    }
}
