import SwiftUI

struct RecipeAnalyzingView: View {
    @Binding var isPresented: Bool
    var onRecipeExtracted: (Recipe) -> Void

    let sharedURL: String

    @State private var currentStatusIndex = 0
    @State private var extractedRecipe: Recipe? = nil

    let statuses = [
        "Opening Reel...",
        "Reading Page Content...",
        "Identifying Ingredients...",
        "Matching Products...",
        "Ready!"
    ]

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 30) {
                Spacer()

                // Animated AI Icon
                ZStack {
                    Circle()
                        .fill(AppTheme.Colors.primary.opacity(0.2))
                        .frame(width: 150, height: 150)
                        .scaleEffect(currentStatusIndex >= 4 ? 1.2 : 1.0)
                        .animation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true), value: currentStatusIndex)

                    Circle()
                        .fill(AppTheme.Colors.primary.opacity(0.4))
                        .frame(width: 100, height: 100)
                        .scaleEffect(currentStatusIndex >= 4 ? 1.4 : 1.0)
                        .animation(.easeInOut(duration: 0.6).repeatForever(autoreverses: true), value: currentStatusIndex)

                    Image(systemName: currentStatusIndex >= 4 ? "checkmark" : "wand.and.stars")
                        .font(.system(size: 40, weight: .bold))
                        .foregroundColor(.white)
                        .contentTransition(.symbolEffect(.replace))
                }

                Text("Recipe to Blinkit")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.white)

                Text(statuses[min(currentStatusIndex, statuses.count - 1)])
                    .font(.headline)
                    .foregroundColor(.white.opacity(0.8))
                    .transition(.opacity)
                    .id(currentStatusIndex)
                    .animation(.easeInOut(duration: 0.3), value: currentStatusIndex)

                // Progress dots
                HStack(spacing: 8) {
                    ForEach(0..<statuses.count, id: \.self) { index in
                        Circle()
                            .fill(index <= currentStatusIndex ? AppTheme.Colors.primary : Color.white.opacity(0.2))
                            .frame(width: 6, height: 6)
                            .animation(.easeInOut, value: currentStatusIndex)
                    }
                }

                // Show URL being processed
                if !sharedURL.isEmpty && sharedURL != "no-url" {
                    Text(sharedURL.prefix(60) + (sharedURL.count > 60 ? "..." : ""))
                        .font(.caption2)
                        .foregroundColor(.white.opacity(0.3))
                        .lineLimit(1)
                        .padding(.horizontal, 32)
                }

                Spacer()
            }
        }
        .onAppear {
            runPipeline()
        }
    }

    private func runPipeline() {
        Task {
            // Step 1: Opening
            withAnimation { currentStatusIndex = 0 }
            try? await Task.sleep(for: .milliseconds(500))

            // Step 2: Reading — this is where the real network call happens
            withAnimation { currentStatusIndex = 1 }
            let recipe = await RecipeExtractionService.shared.extractRecipe(from: sharedURL)

            // Step 3: Identifying
            withAnimation { currentStatusIndex = 2 }
            try? await Task.sleep(for: .milliseconds(600))

            // Step 4: Matching
            withAnimation { currentStatusIndex = 3 }
            try? await Task.sleep(for: .milliseconds(500))

            // Step 5: Done!
            withAnimation { currentStatusIndex = 4 }
            try? await Task.sleep(for: .milliseconds(500))

            // Deliver the recipe and dismiss
            await MainActor.run {
                isPresented = false
                onRecipeExtracted(recipe)
            }
        }
    }
}
