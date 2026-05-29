
import SwiftUI
import SwiftData

@main
struct FridgeFlixApp: App {

    @StateObject private var authVM    = AuthViewModel()
    @StateObject private var profileVM = ProfileViewModel()

    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            UserProfile.self,
            Recipe.self,
            MasterIngredient.self,
            MasterDietTag.self,
            PendingContent.self
        ])
        let config = ModelConfiguration(isStoredInMemoryOnly: false)
        do {
            return try ModelContainer(for: schema, configurations: [config])
        } catch {
            fatalError("Failed to create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(authVM)
                .environmentObject(profileVM)
        }
        .modelContainer(sharedModelContainer)

        #if os(macOS)
        .commands {
            CommandGroup(replacing: .appInfo) {
                Button("About FridgeFlix") {}
            }
        }
        #endif
    }
}
