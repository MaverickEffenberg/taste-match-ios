import SwiftUI
import SwiftData
import Auth
import Supabase
import AVFoundation

@main
struct TasteMatchApp: App {

    @StateObject private var authVM    = AuthViewModel()
    @StateObject private var profileVM = ProfileViewModel()

    init() {
        do {
            // Memaksa suara video tetap menyala meskipun iPhone dalam mode Silent
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .moviePlayback)
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            print("Gagal mengatur audio: \(error)")
        }
    }

    var sharedModelContainer: ModelContainer = {
            let schema = Schema([
                UserProfile.self,
                Recipe.self,
                MasterIngredient.self,
                MasterDietTag.self
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
                .onOpenURL { url in
                    // After Google OAuth redirects back to the app, this feeds
                    // the URL into Supabase which completes the token exchange
                    // and fires .signedIn on authStateChanges → AuthViewModel
                    // picks it up and sets currentUser.
                    Task {
                        try? await supabase.auth.session(from: url)
                    }
                }
        }
        .modelContainer(sharedModelContainer)

        #if os(macOS)
        .commands {
            CommandGroup(replacing: .appInfo) {
                // Identitas yang benar!
                Button("About Taste Match") {}
            }
        }
        #endif
    }
}
