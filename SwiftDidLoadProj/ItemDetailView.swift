import SwiftUI

struct ItemDetailView: View {
    let item: Item
    @Environment(AppViewModel.self) var viewModel
    @Environment(\.dismiss) var dismiss
    
    @State private var showDetailsSheet = false
    
    var body: some View {
        ZStack(alignment: .bottom) {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    
                    // Top Image Area
                    ZStack(alignment: .top) {
                        Rectangle()
                            .fill(Color(white: 0.95))
                            .frame(height: 350)
                        
                        if let url = item.imageURL {
                            CachedAsyncImage(url: url) { image in
                                image
                                    .resizable()
                                    .scaledToFit()
                                    .padding(40)
                            } placeholder: {
                                ProgressView()
                            }
                            .frame(height: 350)
                        }
                        
                        // Custom Nav Bar Overlay
                        HStack {
                            Button(action: {
                                dismiss()
                            }) {
                                Circle()
                                    .fill(Color.white)
                                    .frame(width: 44, height: 44)
                                    .overlay(
                                        Image(systemName: "chevron.left")
                                            .foregroundColor(.black)
                                    )
                                    .shadow(color: .black.opacity(0.1), radius: 5)
                            }
                            
                            Spacer()
                            
                            HStack(spacing: AppTheme.Spacing.small) {
                                navButton(icon: "heart")
                                navButton(icon: "magnifyingglass")
                                navButton(icon: "square.and.arrow.up")
                            }
                        }
                        .padding(.horizontal, AppTheme.Spacing.medium)
                        .padding(.top, 50) // Safe area padding manually since we ignore it
                    }
                    
                    // Content Area
                    VStack(alignment: .leading, spacing: AppTheme.Spacing.medium) {
                        
                        // Info Chips
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: AppTheme.Spacing.small) {
                                infoChip(title: "Flavour", value: "Masala")
                                infoChip(title: "Shelf Life", value: "8 months")
                                infoChip(title: "Preparation Time", value: "2 minutes")
                                
                                Button(action: {
                                    showDetailsSheet = true
                                }) {
                                    Text("View\ndetails")
                                        .font(.caption2)
                                        .fontWeight(.bold)
                                        .multilineTextAlignment(.center)
                                        .foregroundColor(AppTheme.Colors.primary)
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 8)
                                        .background(AppTheme.Colors.primary.opacity(0.1))
                                        .cornerRadius(8)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 8)
                                                .stroke(AppTheme.Colors.primary, lineWidth: 1)
                                        )
                                }
                            }
                            .padding(.horizontal, AppTheme.Spacing.medium)
                        }
                        .padding(.top, AppTheme.Spacing.medium)
                        .padding(.horizontal, -AppTheme.Spacing.medium)
                        
                        // Title and Rating
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("Bought Earlier")
                                    .font(.caption2)
                                    .fontWeight(.bold)
                                    .foregroundColor(.teal)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Color.teal.opacity(0.1))
                                    .cornerRadius(4)
                                
                                HStack(spacing: 2) {
                                    Image(systemName: "clock")
                                    Text("14 mins")
                                }
                                .font(.caption2)
                                .foregroundColor(AppTheme.Colors.textSecondary)
                                
                                Spacer()
                                
                                HStack(spacing: 2) {
                                    ForEach(0..<5) { _ in
                                        Image(systemName: "star.fill")
                                            .foregroundColor(.yellow)
                                            .font(.caption2)
                                    }
                                    Text("1.9 lac")
                                        .font(.caption2)
                                        .foregroundColor(AppTheme.Colors.textSecondary)
                                }
                            }
                            
                            Text(item.name)
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundColor(AppTheme.Colors.textPrimary)
                        }
                        
                        // Unit Selection
                        VStack(alignment: .leading, spacing: AppTheme.Spacing.small) {
                            Text("Select Unit")
                                .font(.headline)
                                .fontWeight(.bold)
                            
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: AppTheme.Spacing.small) {
                                    unitCard(weight: item.weight, price: item.price, originalPrice: nil, discount: nil, isSelected: true)
                                    unitCard(weight: "3 x \(item.weight)", price: item.price * 3 - 5, originalPrice: item.price * 3, discount: "5% OFF on MRP", isSelected: false)
                                    unitCard(weight: "4 x \(item.weight)", price: item.price * 4 - 10, originalPrice: item.price * 4, discount: "6% OFF on MRP", isSelected: false)
                                }
                                .padding(.horizontal, AppTheme.Spacing.medium)
                                .padding(.vertical, 4)
                            }
                            .padding(.horizontal, -AppTheme.Spacing.medium)
                        }
                        
                        // Brand Section
                        HStack {
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color.yellow.opacity(0.2))
                                .frame(width: 40, height: 40)
                                .overlay(
                                    Text("Maggi")
                                        .font(.caption2)
                                        .fontWeight(.bold)
                                        .foregroundColor(.red)
                                )
                            
                            VStack(alignment: .leading) {
                                Text("Maggi")
                                    .font(.subheadline)
                                    .fontWeight(.bold)
                                Text("Explore all products")
                                    .font(.caption)
                                    .foregroundColor(AppTheme.Colors.textSecondary)
                            }
                            
                            Spacer()
                            
                            Image(systemName: "chevron.right")
                                .foregroundColor(AppTheme.Colors.textSecondary)
                        }
                        .padding()
                        .background(AppTheme.Colors.secondaryBackground.opacity(0.5))
                        .cornerRadius(12)
                        
                        Spacer().frame(height: 120) // Bottom padding for sticky bar
                    }
                    .padding(.horizontal, AppTheme.Spacing.medium)
                }
            }
            .ignoresSafeArea(edges: .top)
            
            // Sticky Bottom Add To Cart Banner
            VStack(spacing: 0) {
                Divider()
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(item.weight)
                            .font(.caption)
                            .foregroundColor(AppTheme.Colors.textSecondary)
                        Text("₹\(item.price)")
                            .font(.title3)
                            .fontWeight(.bold)
                        Text("Inclusive of all taxes")
                            .font(.caption2)
                            .foregroundColor(AppTheme.Colors.textSecondary)
                    }
                    
                    Spacer()
                    
                    Button(action: {
                        viewModel.addToCart(item: item)
                    }) {
                        Text("Add to cart")
                            .font(.headline)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                            .padding(.horizontal, 24)
                            .padding(.vertical, 14)
                            .background(AppTheme.Colors.primary)
                            .cornerRadius(12)
                    }
                }
                .padding(.horizontal, AppTheme.Spacing.medium)
                .padding(.vertical, AppTheme.Spacing.small)
                .background(Color(.systemBackground))
            }
        }
        .navigationBarHidden(true)
        .sheet(isPresented: $showDetailsSheet) {
            KeyInformationSheet(item: item)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
    }
    
    // MARK: - Subviews
    
    private func navButton(icon: String) -> some View {
        Button(action: {}) {
            Circle()
                .fill(Color.white)
                .frame(width: 44, height: 44)
                .overlay(
                    Image(systemName: icon)
                        .foregroundColor(.black)
                )
                .shadow(color: .black.opacity(0.1), radius: 5)
        }
    }
    
    private func infoChip(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption2)
                .foregroundColor(AppTheme.Colors.textSecondary)
            Text(value)
                .font(.caption)
                .fontWeight(.bold)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color.white)
        .cornerRadius(8)
        .shadow(color: .black.opacity(0.05), radius: 2)
    }
    
    private func unitCard(weight: String, price: Int, originalPrice: Int?, discount: String?, isSelected: Bool) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(weight)
                .font(.subheadline)
                .fontWeight(.bold)
            
            HStack(alignment: .bottom, spacing: 4) {
                Text("₹\(price)")
                    .font(.subheadline)
                    .fontWeight(.bold)
                if let original = originalPrice {
                    Text("₹\(original)")
                        .font(.caption2)
                        .strikethrough()
                        .foregroundColor(AppTheme.Colors.textSecondary)
                }
            }
            
            if let disc = discount {
                Text(disc)
                    .font(.caption2)
                    .fontWeight(.bold)
                    .foregroundColor(.blue)
            }
        }
        .padding()
        .background(isSelected ? AppTheme.Colors.primary.opacity(0.1) : Color.white)
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(isSelected ? AppTheme.Colors.primary : Color(.systemGray4), lineWidth: 1)
        )
    }
}
