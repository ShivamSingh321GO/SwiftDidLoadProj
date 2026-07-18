import SwiftUI

struct ContentView: View {
    @State private var viewModel = AppViewModel()
    @State private var navigateToSpaces = false
    @State private var searchText = ""
    
    let columns = [
        GridItem(.flexible(), spacing: AppTheme.Spacing.medium),
        GridItem(.flexible(), spacing: AppTheme.Spacing.medium),
        GridItem(.flexible(), spacing: AppTheme.Spacing.medium)
    ]
    
    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                ScrollView {
                    VStack(alignment: .leading, spacing: AppTheme.Spacing.medium) {
                        CategoriesRowView()
                        
                        Divider()
                        
                        SectionHeaderView()
                        
                        LazyVGrid(columns: columns, spacing: AppTheme.Spacing.medium) {
                            ForEach(AppViewModel.sampleItems) { item in
                                ItemCardView(item: item)
                                    .environment(viewModel)
                            }
                        }
                        .padding(.horizontal, AppTheme.Spacing.medium)
                        
                        // Bottom Padding for floating button
                        Spacer().frame(height: 100)
                    }
                }
                
                // Floating Cart Button
                FloatingCartButton {
                    navigateToSpaces = true
                }
            }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $searchText, placement: .navigationBarDrawer(displayMode: .always), prompt: "Search for atta, dal, coke and more")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: {
                        // Profile action
                    }) {
                        Image(systemName: "person.crop.circle.fill")
                            .foregroundColor(AppTheme.Colors.textPrimary)
                    }
                }
            }
            .navigationDestination(isPresented: $navigateToSpaces) {
                SpacesView()
                    .environment(viewModel)
            }
        }
    }
}

// MARK: - Components


struct CategoriesRowView: View {
    var body: some View {
        HStack(spacing: AppTheme.Spacing.large) {
            CategoryItem(icon: "bag.fill", title: "All")
            CategoryItem(icon: "umbrella.fill", title: "Monsoon")
            CategoryItem(icon: "headphones", title: "Electronics")
            CategoryItem(icon: "sparkles", title: "Beauty")
            CategoryItem(icon: "lamp.table.fill", title: "Decor")
        }
        .padding(.horizontal, AppTheme.Spacing.medium)
    }
}

struct SectionHeaderView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.extraSmall) {
            Text("Explore the range of noodles & pasta")
                .font(.title3)
                .fontWeight(.bold)
            Text("Because you bought instant noodles")
                .font(.subheadline)
                .foregroundColor(AppTheme.Colors.textSecondary)
        }
        .padding(.horizontal, AppTheme.Spacing.medium)
    }
}

struct FloatingCartButton: View {
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                VStack(alignment: .center, spacing: 2) {
                    Text("View cart")
                        .font(.headline)
                        .fontWeight(.bold)
                }
                
                ZStack {
                    Circle()
                        .fill(Color.black.opacity(0.15))
                        .frame(width: 32, height: 32)
                    Image(systemName: "chevron.right")
                        .font(.body.weight(.bold))
                }
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 20)
            .background(AppTheme.Colors.primary)
            .foregroundColor(.white)
            .clipShape(Capsule())
            .padding(.horizontal, AppTheme.Spacing.medium)
            .padding(.bottom, 20)
            .shadow(color: .black.opacity(0.15), radius: 5, y: 3)
        }
    }
}

struct CategoryItem: View {
    let icon: String
    let title: String
    
    var body: some View {
        VStack {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(AppTheme.Colors.textPrimary)
            Text(title)
                .font(.caption)
                .foregroundColor(AppTheme.Colors.textPrimary)
        }
    }
}

struct ItemCardView: View {
    let item: Item
    @Environment(AppViewModel.self) var viewModel
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Image Box with overlays
            RoundedRectangle(cornerRadius: AppTheme.Spacing.cornerRadius)
                .fill(AppTheme.Colors.secondaryBackground)
                .frame(height: 110)
                .overlay(alignment: .topTrailing) {
                    Image(systemName: "heart")
                        .foregroundColor(AppTheme.Colors.textSecondary)
                        .padding(AppTheme.Spacing.small)
                }
                .overlay(alignment: .bottomTrailing) {
                    ZStack {
                        Rectangle()
                            .stroke(AppTheme.Colors.primary, lineWidth: 1)
                            .frame(width: 12, height: 12)
                        Circle()
                            .fill(AppTheme.Colors.primary)
                            .frame(width: 6, height: 6)
                    }
                    .padding(2)
                    .background(AppTheme.Colors.background)
                    .cornerRadius(2)
                    .padding(AppTheme.Spacing.smallCornerRadius)
                }
            
            // Weight and ADD Button row
            HStack(alignment: .center, spacing: AppTheme.Spacing.extraSmall) {
                Text(item.weight)
                    .font(.caption2)
                    .foregroundColor(AppTheme.Colors.textSecondary)
                
                Spacer(minLength: 0)
                
                Button(action: {
                    viewModel.addToCart(item: item)
                }) {
                    Text("ADD")
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundColor(AppTheme.Colors.primary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, AppTheme.Spacing.smallCornerRadius)
                        .background(AppTheme.Colors.background)
                        .cornerRadius(AppTheme.Spacing.smallCornerRadius)
                        .overlay(
                            RoundedRectangle(cornerRadius: AppTheme.Spacing.smallCornerRadius)
                                .stroke(AppTheme.Colors.primary, lineWidth: 1)
                        )
                }
                .offset(y: -10)
            }
            .padding(.top, AppTheme.Spacing.extraSmall)
            .padding(.bottom, -6)
            
            // Text Content Area
            VStack(alignment: .leading, spacing: AppTheme.Spacing.extraSmall) {
                // Price
                HStack(alignment: .bottom, spacing: AppTheme.Spacing.extraSmall) {
                    Text("₹\(item.price)")
                        .font(.subheadline)
                        .fontWeight(.bold)
                    if let original = item.originalPrice {
                        Text("₹\(original)")
                            .font(.caption2)
                            .strikethrough()
                            .foregroundColor(AppTheme.Colors.textSecondary)
                    }
                }
                
                // Discount (or empty space to align)
                if let discount = item.discount {
                    Text(discount)
                        .font(.caption2)
                        .fontWeight(.medium)
                        .foregroundColor(AppTheme.Colors.discountText)
                } else {
                    Text(" ")
                        .font(.caption2)
                }
                
                // Item Name
                Text(item.name)
                    .font(.caption2)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                    .frame(height: 32, alignment: .topLeading)
                
                // Delivery Time
                HStack(spacing: 2) {
                    Image(systemName: "clock")
                        .font(.caption2)
                        .foregroundColor(AppTheme.Colors.textSecondary)
                    Text("22 mins")
                        .font(.caption2)
                        .foregroundColor(AppTheme.Colors.textSecondary)
                }
            }
        }
    }
}

#Preview {
    ContentView()
}
