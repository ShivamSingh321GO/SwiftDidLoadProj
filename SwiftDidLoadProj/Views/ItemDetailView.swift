import SwiftUI

struct ItemDetailView: View {
    let item: Item
    @Environment(AppViewModel.self) var viewModel
    @Environment(\.dismiss) var dismiss
    
    @State private var showDetailsSheet = false
    @State private var navigateToCarts = false
    @State private var showingSpaceSelectionSheet = false
    @State private var showingCreateSpace = false
    @State private var newSpaceName = ""
    
    @State private var selectedUnitIndex = 0
    
    var selectedUnitItem: Item {
        switch selectedUnitIndex {
        case 1:
            return Item(
                id: "\(item.id)-pack3",
                name: item.name,
                price: item.price * 3 - 5,
                originalPrice: item.price * 3,
                weight: "3 x \(item.weight)",
                discount: "5% OFF on MRP",
                imageURL: item.imageURL,
                brand: item.brand,
                category: item.category,
                subCategory: item.subCategory,
                rating: item.rating,
                ratingCount: item.ratingCount,
                aliases: item.aliases
            )
        case 2:
            return Item(
                id: "\(item.id)-pack4",
                name: item.name,
                price: item.price * 4 - 10,
                originalPrice: item.price * 4,
                weight: "4 x \(item.weight)",
                discount: "6% OFF on MRP",
                imageURL: item.imageURL,
                brand: item.brand,
                category: item.category,
                subCategory: item.subCategory,
                rating: item.rating,
                ratingCount: item.ratingCount,
                aliases: item.aliases
            )
        default:
            return item
        }
    }
    
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
                        

                    }
                    
                    // Content Area
                    VStack(alignment: .leading, spacing: AppTheme.Spacing.medium) {
                        
                        // Info Chips Row
                        HStack(spacing: AppTheme.Spacing.small) {
                            infoChip(title: "Flavour", value: "Masala")
                            infoChip(title: "Shelf Life", value: "8 months")
                            infoChip(title: "Prep Time", value: "2 mins")
                            
                            Button(action: {
                                showDetailsSheet = true
                            }) {
                                VStack(spacing: 2) {
                                    Text("View")
                                    Text("details")
                                }
                                .font(.system(size: 10, weight: .bold))
                                .multilineTextAlignment(.center)
                                .foregroundColor(AppTheme.Colors.primary)
                                .frame(maxWidth: .infinity, minHeight: 52)
                                .background(AppTheme.Colors.primary.opacity(0.1))
                                .cornerRadius(8)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(AppTheme.Colors.primary, lineWidth: 1)
                                )
                            }
                            .buttonStyle(.plain)
                            .frame(maxWidth: .infinity)
                        }
                        .padding(.top, AppTheme.Spacing.medium)
                        
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
                                     let ratingVal = item.rating ?? 5.0
                                     let ratingCountVal = item.ratingCount ?? "1.9 lac"
                                     
                                     Image(systemName: "star.fill")
                                         .foregroundColor(.yellow)
                                         .font(.caption2)
                                     
                                     Text(String(format: "%.1f", ratingVal))
                                         .font(.caption2.weight(.bold))
                                         .foregroundColor(AppTheme.Colors.textPrimary)
                                     
                                     Text("(\(ratingCountVal))")
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
                                    unitCard(weight: item.weight, price: item.price, originalPrice: nil, discount: nil, isSelected: selectedUnitIndex == 0)
                                        .onTapGesture {
                                            withAnimation {
                                                selectedUnitIndex = 0
                                            }
                                        }
                                    
                                    unitCard(weight: "3 x \(item.weight)", price: item.price * 3 - 5, originalPrice: item.price * 3, discount: "5% OFF on MRP", isSelected: selectedUnitIndex == 1)
                                        .onTapGesture {
                                            withAnimation {
                                                selectedUnitIndex = 1
                                            }
                                        }
                                    
                                    unitCard(weight: "4 x \(item.weight)", price: item.price * 4 - 10, originalPrice: item.price * 4, discount: "6% OFF on MRP", isSelected: selectedUnitIndex == 2)
                                        .onTapGesture {
                                            withAnimation {
                                                selectedUnitIndex = 2
                                            }
                                        }
                                }
                                .padding(.horizontal, AppTheme.Spacing.medium)
                                .padding(.vertical, 4)
                            }
                            .padding(.horizontal, -AppTheme.Spacing.medium)
                        }
                        
                        // Brand Section
                        let brandName = item.brand ?? "Unknown Brand"
                        HStack {
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color.yellow.opacity(0.2))
                                .frame(width: 40, height: 40)
                                .overlay(
                                    Text(brandName.prefix(1))
                                        .font(.headline)
                                        .fontWeight(.bold)
                                        .foregroundColor(.red)
                                )
                            
                            VStack(alignment: .leading) {
                                Text(brandName)
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
                        
                        Spacer().frame(height: viewModel.activeCartItemsCount > 0 ? 200 : 120) // Bottom padding for sticky bar
                    }
                    .padding(.horizontal, AppTheme.Spacing.medium)
                }
            }
            .ignoresSafeArea(edges: .top)
            
            // Sticky Bottom & Floating Cart Button stack
            VStack(spacing: 0) {
                if viewModel.activeCartItemsCount > 0 {
                    FloatingCartButton(
                        itemCount: viewModel.activeCartItemsCount,
                        isSpacesEnabled: viewModel.isSpacesEnabled,
                        activeSpaceName: viewModel.selectedCart?.name,
                        onChangeSpace: {
                            showingSpaceSelectionSheet = true
                        },
                        action: {
                            navigateToCarts = true
                        }
                    )
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .padding(.bottom, 8)
                }
                
                // Sticky Bottom Add To Cart Banner
                VStack(spacing: 0) {
                    Divider()
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(selectedUnitItem.weight)
                                .font(.caption)
                                .foregroundColor(AppTheme.Colors.textSecondary)
                            Text("₹\(selectedUnitItem.price)")
                                .font(.title3)
                                .fontWeight(.bold)
                            Text("Inclusive of all taxes")
                                .font(.caption2)
                                .foregroundColor(AppTheme.Colors.textSecondary)
                        }
                        
                        Spacer()
                        
                        let qty = viewModel.quantityInCart(of: selectedUnitItem)
                        if qty > 0 {
                            HStack(spacing: 16) {
                                Button(action: {
                                    viewModel.removeFromCart(item: selectedUnitItem)
                                }) {
                                    Image(systemName: "minus")
                                        .font(.headline.weight(.bold))
                                        .foregroundColor(.white)
                                        .frame(width: 40, height: 40)
                                        .background(AppTheme.Colors.primary)
                                        .cornerRadius(10)
                                }
                                
                                Text("\(qty)")
                                    .font(.title3)
                                    .fontWeight(.bold)
                                    .foregroundColor(AppTheme.Colors.textPrimary)
                                    .frame(minWidth: 20)
                                    .multilineTextAlignment(.center)
                                
                                Button(action: {
                                    viewModel.addToCart(item: selectedUnitItem)
                                }) {
                                    Image(systemName: "plus")
                                        .font(.headline.weight(.bold))
                                        .foregroundColor(.white)
                                        .frame(width: 40, height: 40)
                                        .background(AppTheme.Colors.primary)
                                        .cornerRadius(10)
                                }
                            }
                        } else {
                            Button(action: {
                                viewModel.addToCart(item: selectedUnitItem)
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
                    }
                    .padding(.horizontal, AppTheme.Spacing.medium)
                    .padding(.vertical, AppTheme.Spacing.small)
                    .background(Color(.systemBackground))
                }
            }
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                HStack(spacing: 16) {
                    Button(action: {}) {
                        Image(systemName: "heart")
                    }
                    Button(action: {}) {
                        Image(systemName: "magnifyingglass")
                    }
                    Button(action: {}) {
                        Image(systemName: "square.and.arrow.up")
                    }
                }
                .foregroundColor(.black)
            }
        }
        .sheet(isPresented: $showDetailsSheet) {
            KeyInformationSheet(item: item)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showingSpaceSelectionSheet) {
            SpaceSelectionSheet(viewModel: viewModel, showingCreateSpace: $showingCreateSpace)
                .presentationDetents([.medium])
                .presentationDragIndicator(.visible)
        }
        .alert("Create New Space", isPresented: $showingCreateSpace) {
            TextField("Space Name", text: $newSpaceName)
            Button("Cancel", role: .cancel) {
                newSpaceName = ""
            }
            Button("Create") {
                if !newSpaceName.isEmpty {
                    withAnimation {
                        viewModel.createCart(name: newSpaceName, makeActive: true)
                    }
                }
                newSpaceName = ""
            }
        } message: {
            Text("Enter a name for your new space.")
        }
        .navigationDestination(isPresented: $navigateToCarts) {
            CartDetailView(cartId: viewModel.selectedCartId)
                .environment(viewModel)
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
                .font(.system(size: 9))
                .foregroundColor(AppTheme.Colors.textSecondary)
                .lineLimit(1)
            Text(value)
                .font(.caption)
                .fontWeight(.bold)
                .lineLimit(1)
                .minimumScaleFactor(0.85)
        }
        .padding(.horizontal, 8)
        .frame(maxWidth: .infinity, minHeight: 52, alignment: .leading)
        .background(Color.white)
        .cornerRadius(8)
        .shadow(color: .black.opacity(0.05), radius: 2)
    }
    
    private func unitCard(weight: String, price: Int, originalPrice: Int?, discount: String?, isSelected: Bool) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(weight)
                .font(.subheadline)
                .fontWeight(.bold)
                .lineLimit(1)
                .minimumScaleFactor(0.85)
            
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
                    .font(.system(size: 9, weight: .bold))
                    .foregroundColor(.blue)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
        }
        .padding(10)
        .frame(width: 115, height: 85, alignment: .leading)
        .background(isSelected ? AppTheme.Colors.primary.opacity(0.1) : Color.white)
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(isSelected ? AppTheme.Colors.primary : Color(.systemGray4), lineWidth: 1)
        )
    }
}
