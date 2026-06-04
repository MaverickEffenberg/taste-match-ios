import SwiftUI

struct KitchenAssistantView: View {
    @Environment(\.horizontalSizeClass) var sizeClass
    
    // Menerima data dari luar agar FeedView tidak kelaparan
    @ObservedObject var viewModel: FeedViewModel
    @ObservedObject var profileVM: ProfileViewModel
    
    var body: some View {
        if sizeClass == .regular {
            NavigationSplitView {
                ZStack {
                    Color.black.edgesIgnoringSafeArea(.all)
                    VStack {
                        Text("▶️ Video Sedang Berputar...")
                            .font(.largeTitle)
                            .foregroundColor(.white)
                    }
                }
                .navigationTitle("Pusat Video")
            } detail: {
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        Text("Instruksi Memasak")
                            .font(.largeTitle).bold()
                        Divider()
                        Text("Daftar Bahan:")
                            .font(.headline)
                        ForEach(["Garam", "Bawang", "Cabai"], id: \.self) { item in
                            HStack {
                                Image(systemName: "circle")
                                Text(item)
                            }
                            .foregroundColor(.primary)
                        }
                    }
                    .padding()
                }
                .navigationTitle("Detail Resep")
            }
        } else {
            // Memberi makan FeedView dengan parameter yang diminta!
            FeedView(viewModel: viewModel, profileVM: profileVM)
        }
    }
}
