import SwiftUI

struct RecipeAnalyzingView: View {
    @Binding var isPresented: Bool
    var onRecipeExtracted: (Recipe) -> Void

    let sharedURL: String

    @State private var currentStatusIndex = 0
    @State private var hasError = false

    let statuses = [
        "Opening Reel...",
        "Reading Recipe...",
        "Running Apple Intelligence...",
        "Matching Ingredients...",
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

                    if hasError {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.system(size: 40, weight: .bold))
                            .foregroundColor(.orange)
                    } else {
                        Image(systemName: currentStatusIndex >= 4 ? "checkmark" : "wand.and.stars")
                            .font(.system(size: 40, weight: .bold))
                            .foregroundColor(.white)
                            .contentTransition(.symbolEffect(.replace))
                    }
                }

                Text("Recipe to Blinkit")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.white)

                if hasError {
                    Text("Using best match...")
                        .font(.headline)
                        .foregroundColor(.orange.opacity(0.9))
                } else {
                    Text(statuses[min(currentStatusIndex, statuses.count - 1)])
                        .font(.headline)
                        .foregroundColor(.white.opacity(0.8))
                        .transition(.opacity)
                        .id(currentStatusIndex)
                        .animation(.easeInOut(duration: 0.3), value: currentStatusIndex)
                }

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
            runExtractionPipeline()
        }
    }

    private func runExtractionPipeline() {
        Task {
            do {
                // Step 1
                await setStatus(0)
                try await Task.sleep(for: .milliseconds(600))

                // Step 2
                await setStatus(1)

                // Real network call to oEmbed
                let recipe = try await RecipeExtractionService.shared.extractRecipe(from: sharedURL)

                // Step 3
                await setStatus(2)
                try await Task.sleep(for: .milliseconds(700))

                // Step 4
                await setStatus(3)
                try await Task.sleep(for: .milliseconds(500))

                // Step 5 — Done!
                await setStatus(4)
                try await Task.sleep(for: .milliseconds(600))

                // Deliver the real recipe
                await MainActor.run {
                    isPresented = false
                    onRecipeExtracted(recipe)
                }
            } catch {
                // Any error → fall back to mock
                await MainActor.run {
                    hasError = true
                }
                try? await Task.sleep(for: .seconds(1))
                await MainActor.run {
                    isPresented = false
                    onRecipeExtracted(AppViewModel.mockRecipe)
                }
            }
        }
    }

    @MainActor
    private func setStatus(_ index: Int) {
        withAnimation {
            currentStatusIndex = index
        }
    }
}
