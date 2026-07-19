import SwiftUI

struct RecipeShoppingView: View {
    let recipe: Recipe
    @Environment(AppViewModel.self) var viewModel
    @Environment(\.dismiss) var dismiss

    var body: some View {
        VStack(spacing: 0) {
            navigationHeader
            ingredientScrollView
        }
        .navigationBarHidden(true)
        .overlay(alignment: .bottom) {
            if viewModel.activeCartItemsCount > 0 {
                FloatingCartButton(
                    itemCount: viewModel.activeCartItemsCount,
                    isSpacesEnabled: viewModel.isSpacesEnabled,
                    activeSpaceName: viewModel.selectedCart?.name,
                    onChangeSpace: {},
                    action: { dismiss() }
                )
            }
        }
    }

    // MARK: - Navigation Header

    private var navigationHeader: some View {
        HStack {
            Button(action: { dismiss() }) {
                Image(systemName: "chevron.left")
                    .font(.title2)
                    .foregroundColor(AppTheme.Colors.textPrimary)
            }

            Spacer()

            VStack(spacing: 2) {
                Text("AI Found")
                    .font(.caption)
                    .foregroundColor(AppTheme.Colors.textSecondary)
                Text(recipe.name)
                    .font(.headline)
                    .fontWeight(.bold)
                    .foregroundColor(AppTheme.Colors.textPrimary)
                    .lineLimit(1)
            }

            Spacer()

            Image(systemName: "chevron.left")
                .font(.title2)
                .foregroundColor(.clear)
        }
        .padding()
        .background(Color(.systemBackground))
        .shadow(color: .black.opacity(0.05), radius: 2, y: 2)
    }

    // MARK: - Main Scroll Content

    private var ingredientScrollView: some View {
        ScrollView {
            VStack(spacing: AppTheme.Spacing.large) {
                aiBanner
                    .padding(.horizontal, AppTheme.Spacing.medium)
                    .padding(.top, AppTheme.Spacing.medium)

                if !recipe.ingredients.isEmpty {
                    aiIngredientChips
                        .padding(.horizontal, AppTheme.Spacing.medium)

                    ForEach(recipe.ingredients) { ingredient in
                        let matches = viewModel.products(for: ingredient)
                        if matches.isEmpty {
                            // Always show the ingredient as plain text even with no catalog match
                            NotAvailableRow(name: ingredient.genericName)
                                .padding(.horizontal, AppTheme.Spacing.medium)
                        } else {
                            IngredientProductSection(
                                ingredient: ingredient,
                                products: matches
                            )
                            .environment(viewModel)
                        }
                    }
                } else {
                    // Safety net — should never reach here with current service, but just in case
                    VStack(spacing: AppTheme.Spacing.small) {
                        Image(systemName: "wand.and.stars.inverse")
                            .font(.largeTitle)
                            .foregroundColor(AppTheme.Colors.textSecondary)
                        Text("Share a food reel to get started.")
                            .font(.subheadline)
                            .foregroundColor(AppTheme.Colors.textSecondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.top, 60)
                    .padding(.horizontal, AppTheme.Spacing.large)
                }

                Spacer().frame(height: 100)
            }
        }
    }

    // MARK: - AI Banner

    private var aiBanner: some View {
        HStack(spacing: AppTheme.Spacing.medium) {
            Image(systemName: "wand.and.stars")
                .foregroundColor(.yellow)
                .font(.title2)

            VStack(alignment: .leading, spacing: 4) {
                Text("Apple Intelligence Extracted")
                    .font(.subheadline)
                    .fontWeight(.bold)
                Text(recipe.ingredients.isEmpty
                     ? "Share a recipe reel to see results."
                     : "\(recipe.ingredients.count) item\(recipe.ingredients.count == 1 ? "" : "s") identified from your reel.")
                    .font(.caption)
                    .foregroundColor(AppTheme.Colors.textSecondary)
            }
            Spacer()
        }
        .padding()
        .background(Color.yellow.opacity(0.1))
        .cornerRadius(AppTheme.Spacing.cornerRadius)
    }

    // MARK: - Ingredient Chip Row

    private var aiIngredientChips: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.small) {
            HStack(spacing: 4) {
                Image(systemName: "sparkles")
                    .font(.caption2)
                    .foregroundColor(AppTheme.Colors.primary)
                Text("All extracted items")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(AppTheme.Colors.textSecondary)
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: AppTheme.Spacing.small) {
                    ForEach(recipe.ingredients) { ingredient in
                        let available = !viewModel.products(for: ingredient).isEmpty
                        IngredientChip(name: ingredient.genericName, isAvailable: available)
                    }
                }
            }
        }
    }
}

// MARK: - Ingredient Product Section (has catalog matches)

private struct IngredientProductSection: View {
    let ingredient: RecipeIngredient
    let products: [Item]
    @Environment(AppViewModel.self) var viewModel

    var body: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.small) {
            HStack {
                Text(ingredient.genericName)
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundColor(AppTheme.Colors.textPrimary)

                Spacer()

                Text("\(products.count) option\(products.count == 1 ? "" : "s")")
                    .font(.caption)
                    .foregroundColor(AppTheme.Colors.textSecondary)
            }
            .padding(.horizontal, AppTheme.Spacing.medium)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: AppTheme.Spacing.medium) {
                    ForEach(products) { product in
                        ItemCardView(item: product)
                            .environment(viewModel)
                            .frame(width: 160)
                    }
                }
                .padding(.horizontal, AppTheme.Spacing.medium)
                .padding(.bottom, AppTheme.Spacing.small)
            }
        }
    }
}

// MARK: - Not Available Row
// Always shown — in plain text — when an AI-extracted item has no catalog match.

private struct NotAvailableRow: View {
    let name: String

    var body: some View {
        HStack(spacing: AppTheme.Spacing.medium) {
            ZStack {
                Circle()
                    .fill(Color(.systemGray5))
                    .frame(width: 44, height: 44)
                Image(systemName: "cart.badge.questionmark")
                    .font(.body)
                    .foregroundColor(Color(.systemGray2))
            }

            VStack(alignment: .leading, spacing: 4) {
                // Plain text name — always visible
                Text(name)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(AppTheme.Colors.textPrimary)
                Text("Not available on Blinkit right now")
                    .font(.caption)
                    .foregroundColor(AppTheme.Colors.textSecondary)
            }

            Spacer()

            Text("Unavailable")
                .font(.caption2)
                .fontWeight(.medium)
                .foregroundColor(Color(.systemGray))
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color(.systemGray5))
                .clipShape(Capsule())
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(AppTheme.Spacing.cornerRadius)
    }
}

// MARK: - Ingredient Chip

private struct IngredientChip: View {
    let name: String
    let isAvailable: Bool

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: isAvailable ? "checkmark.circle.fill" : "xmark.circle.fill")
                .font(.caption2)
                .foregroundColor(isAvailable ? AppTheme.Colors.primary : Color(.systemGray3))
            Text(name)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(isAvailable ? AppTheme.Colors.primary : AppTheme.Colors.textSecondary)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(isAvailable ? AppTheme.Colors.primary.opacity(0.1) : Color(.systemGray5))
        .clipShape(Capsule())
        .overlay(
            Capsule()
                .stroke(
                    isAvailable ? AppTheme.Colors.primary.opacity(0.4) : Color(.systemGray3),
                    lineWidth: 0.5
                )
        )
    }
}
