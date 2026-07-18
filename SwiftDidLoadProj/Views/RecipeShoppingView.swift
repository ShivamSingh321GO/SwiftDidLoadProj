import SwiftUI

struct RecipeShoppingView: View {
    let recipe: Recipe
    @Environment(AppViewModel.self) var viewModel
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Button(action: {
                    dismiss()
                }) {
                    Image(systemName: "chevron.left")
                        .font(.title2)
                        .foregroundColor(AppTheme.Colors.textPrimary)
                }
                
                Spacer()
                
                VStack {
                    Text("Recipe Space")
                        .font(.caption)
                        .foregroundColor(AppTheme.Colors.textSecondary)
                    Text(recipe.name)
                        .font(.headline)
                        .fontWeight(.bold)
                        .foregroundColor(AppTheme.Colors.textPrimary)
                }
                
                Spacer()
                
                // Placeholder to balance the chevron
                Image(systemName: "chevron.left")
                    .font(.title2)
                    .foregroundColor(.clear)
            }
            .padding()
            .background(Color(.systemBackground))
            .shadow(color: .black.opacity(0.05), radius: 2, y: 2)
            
            // Ingredients List
            ScrollView {
                VStack(spacing: AppTheme.Spacing.large) {
                    
                    // Recipe Summary Banner
                    HStack {
                        Image(systemName: "wand.and.stars")
                            .foregroundColor(.yellow)
                            .font(.title2)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("AI Extracted Ingredients")
                                .font(.subheadline)
                                .fontWeight(.bold)
                            Text("Swipe horizontally to choose your preferred brands.")
                                .font(.caption)
                                .foregroundColor(AppTheme.Colors.textSecondary)
                        }
                        Spacer()
                    }
                    .padding()
                    .background(Color.yellow.opacity(0.1))
                    .cornerRadius(12)
                    .padding(.horizontal, AppTheme.Spacing.medium)
                    .padding(.top, AppTheme.Spacing.medium)
                    
                    // Ingredient Sections
                    ForEach(recipe.ingredients) { ingredient in
                        let matchedProducts = viewModel.products(for: ingredient)
                        
                        if !matchedProducts.isEmpty {
                            VStack(alignment: .leading, spacing: AppTheme.Spacing.small) {
                                // Section Title
                                HStack {
                                    Text(ingredient.genericName)
                                        .font(.title3)
                                        .fontWeight(.bold)
                                        .foregroundColor(AppTheme.Colors.textPrimary)
                                    
                                    Spacer()
                                    
                                    Text("\(matchedProducts.count) options")
                                        .font(.caption)
                                        .foregroundColor(AppTheme.Colors.textSecondary)
                                }
                                .padding(.horizontal, AppTheme.Spacing.medium)
                                
                                // Horizontal Product Carousel
                                ScrollView(.horizontal, showsIndicators: false) {
                                    HStack(spacing: AppTheme.Spacing.medium) {
                                        ForEach(matchedProducts) { product in
                                            ItemCardView(item: product)
                                                .environment(viewModel)
                                                .frame(width: 160) // fixed width for horizontal carousel
                                        }
                                    }
                                    .padding(.horizontal, AppTheme.Spacing.medium)
                                    .padding(.bottom, AppTheme.Spacing.small) // shadow padding
                                }
                            }
                        }
                    }
                    
                    Spacer().frame(height: 100) // Padding for bottom floating cart
                }
            }
        }
        .navigationBarHidden(true)
        .overlay(alignment: .bottom) {
            if viewModel.activeCartItemsCount > 0 {
                FloatingCartButton(
                    itemCount: viewModel.activeCartItemsCount,
                    isSpacesEnabled: viewModel.isSpacesEnabled,
                    activeSpaceName: viewModel.selectedCart?.name,
                    onChangeSpace: {
                        // Normally this would open the space sheet, 
                        // but here we can just leave it empty or add state if needed
                    },
                    action: {
                        dismiss() // For now, dismissing returns them to ContentView where they can open the cart
                    }
                )
            }
        }
    }
}
