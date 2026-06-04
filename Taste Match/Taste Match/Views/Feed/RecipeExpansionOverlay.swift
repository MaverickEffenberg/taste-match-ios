import SwiftUI

struct RecipeExpansionOverlay: View {
    let recipe: Recipe
    let onDismiss: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            VStack(alignment: .leading, spacing: 16) {
                // Indikator Seret (Drag Indicator) yang elegan
                RoundedRectangle(cornerRadius: 3)
                    .fill(Color.secondary)
                    .frame(width: 40, height: 4)
                    .frame(maxWidth: .infinity)

                Text(recipe.title)
                    .font(.title2).bold()
                    .foregroundColor(.primary)
                
                Text("By @\(recipe.creatorUsername)")
                    .font(.subheadline).foregroundColor(.secondary)

                Divider()

                // AREA SCROLLVIEW (Penyelamat UI-mu dari kehancuran!)
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Ingredients")
                            .font(.headline)
                            .foregroundColor(.primary)
                        
                        ForEach(recipe.ingredients, id: \.self) { ingredient in
                            HStack {
                                Image(systemName: "circle")
                                    .foregroundColor(.accentColor)
                                Text(ingredient.capitalized)
                                    .font(.body)
                                    .foregroundColor(.primary) // Konsistensi warna mutlak!
                            }
                        }

                        Divider()

                        Text("Steps")
                            .font(.headline)
                            .foregroundColor(.primary)
                        
                        ForEach(recipe.decodedSteps) { step in
                            HStack(alignment: .top, spacing: 10) {
                                Text("\(step.stepNumber).")
                                    .font(.headline)
                                    .foregroundColor(.accentColor)
                                Text(step.instruction)
                                    .font(.body)
                                    .foregroundColor(.primary) // Konsistensi warna mutlak!
                            }
                        }
                    }
                }
                // Membatasi tinggi kartu maksimal setengah layar
                .frame(maxHeight: UIScreen.main.bounds.height * 0.5)
            }
            .padding()
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 20))
            .shadow(radius: 10)
        }
        .padding(.horizontal)
        .padding(.bottom, 8)
        .onTapGesture(count: 1) {}
        // Tombol Dismiss
        .overlay(alignment: .topTrailing) {
            Button(action: onDismiss) {
                Image(systemName: "xmark.circle.fill")
                    .font(.title2)
                    .foregroundColor(.secondary)
                    .background(Color(UIColor.systemBackground).opacity(0.6))
                    .clipShape(Circle())
            }
            .padding(25)
        }
    }
}
