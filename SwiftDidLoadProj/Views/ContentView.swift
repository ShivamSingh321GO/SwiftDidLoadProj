import SwiftUI

struct ContentView: View {
    @State private var viewModel = AppViewModel()
    @State private var navigateToCarts = false
    @State private var searchText = ""
    @State private var showingCreateSpace = false
    @State private var newSpaceName = ""
    @State private var showingSpaceSelectionSheet = false
    
    let columns = [
        GridItem(.flexible(), spacing: AppTheme.Spacing.medium),
        GridItem(.flexible(), spacing: AppTheme.Spacing.medium),
        GridItem(.flexible(), spacing: AppTheme.Spacing.medium)
    ]
    
    var filteredItems: [Item] {
        if searchText.isEmpty {
            return viewModel.items
        } else {
            return viewModel.items.filter { item in
                item.name.localizedCaseInsensitiveContains(searchText) ||
                (item.brand ?? "").localizedCaseInsensitiveContains(searchText) ||
                (item.aliases ?? []).contains(where: { $0.localizedCaseInsensitiveContains(searchText) })
            }
        }
    }
    
    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                ScrollView {
                    VStack(alignment: .leading, spacing: AppTheme.Spacing.medium) {
                        SpacesHeaderView(viewModel: viewModel, showingSpaceSelectionSheet: $showingSpaceSelectionSheet)
                            .padding(.top, AppTheme.Spacing.small)
                        
                        CategoriesRowView()
                        
                        Divider()
                        
                        SectionHeaderView()
                        
                        Group {
                            if viewModel.items.isEmpty {
                                HStack {
                                    Spacer()
                                    ProgressView("Loading Groceries...")
                                        .padding(.top, 40)
                                    Spacer()
                                }
                            } else {
                                LazyVGrid(columns: columns, spacing: AppTheme.Spacing.medium) {
                                    ForEach(filteredItems) { item in
                                        NavigationLink(value: item) {
                                            ItemCardView(item: item)
                                                .environment(viewModel)
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                            }
                        }
                        .padding(.horizontal, AppTheme.Spacing.medium)
                        
                        // Bottom Padding for floating button
                        Spacer().frame(height: 100)
                    }
                }
                .task {
                    if viewModel.items.isEmpty {
                        await viewModel.fetchGroceries()
                    }
                }
                
                // Floating Cart Button
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
            .sheet(isPresented: $showingSpaceSelectionSheet) {
                SpaceSelectionSheet(viewModel: viewModel, showingCreateSpace: $showingCreateSpace)
                    .presentationDetents([.medium])
                    .presentationDragIndicator(.visible)
            }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $searchText, placement: .navigationBarDrawer(displayMode: .always), prompt: "Search for atta, dal, coke and more")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: {
                        // Profile action
                    }) {
                        Image(systemName: "person")
                            .foregroundColor(AppTheme.Colors.textPrimary)
                    }
                }
            }
            .navigationDestination(isPresented: $navigateToCarts) {
                CartDetailView(cartId: viewModel.selectedCartId)
                    .environment(viewModel)
            }
            .navigationDestination(for: Item.self) { item in
                ItemDetailView(item: item)
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
            Text("Explore the range of products")
                .font(.title3)
                .fontWeight(.bold)
//            Text("Because you bought instant noodles")
//                .font(.subheadline)
//                .foregroundColor(AppTheme.Colors.textSecondary)
        }
        .padding(.horizontal, AppTheme.Spacing.medium)
    }
}

struct FloatingCartButton: View {
    let itemCount: Int
    let isSpacesEnabled: Bool
    let activeSpaceName: String?
    let onChangeSpace: () -> Void
    let action: () -> Void
    
    var body: some View {
        HStack {
            Spacer()
            
            HStack(spacing: 12) {
                // Left side: Text and space selector
                VStack(alignment: .leading, spacing: 2) {
                    Text(itemCount > 0 ? "View cart (\(itemCount))" : "View cart")
                        .font(.subheadline)
                        .fontWeight(.bold)
                    
                    if isSpacesEnabled, let spaceName = activeSpaceName {
                        HStack(spacing: 4) {
                            Text(spaceName)
                                .font(.caption)
                                .fontWeight(.medium)
                                .foregroundColor(.white.opacity(0.9))
                            
                            Button(action: onChangeSpace) {
                                Image(systemName: "chevron.up.chevron.down")
                                    .font(.caption2)
                                    .foregroundColor(.white)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .onTapGesture {
                    action()
                }
                
                Spacer(minLength: 0)
                
                // Right side: Navigate chevron
                Button(action: action) {
                    ZStack {
                        Circle()
                            .fill(Color.black.opacity(0.15))
                            .frame(width: 24, height: 24)
                        Image(systemName: "chevron.right")
                            .font(.caption.weight(.bold))
                    }
                }
                .buttonStyle(.plain)
            }
            .padding(.vertical, 12)
            .padding(.horizontal, 16)
            .frame(width: UIScreen.main.bounds.width * 0.5)
            .background(AppTheme.Colors.primary)
            .foregroundColor(.white)
            .clipShape(Capsule())
            .shadow(color: .black.opacity(0.15), radius: 5, y: 3)
            
            Spacer()
        }
        .padding(.bottom, 20)
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
            ZStack {
                RoundedRectangle(cornerRadius: AppTheme.Spacing.cornerRadius)
                    .fill(AppTheme.Colors.secondaryBackground)
                
                if !item.image.isEmpty {
                    Image(item.image)
                        .resizable()
                        .scaledToFit()
                        .padding(8)
                } else if let url = item.imageURL {
                    CachedAsyncImage(url: url) { image in
                        image
                            .resizable()
                            .scaledToFit()
                    } placeholder: {
                        ProgressView()
                    }
                    .padding(8)
                }
            }
            .frame(height: 110)
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.Spacing.cornerRadius))
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
                
                let qty = viewModel.quantityInCart(of: item)
                if qty > 0 {
                    QuantityStepper(
                        quantity: qty,
                        onIncrement: { viewModel.addToCart(item: item) },
                        onDecrement: { viewModel.removeFromCart(item: item) }
                    )
                    .offset(y: -10)
                } else {
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

struct QuantityStepper: View {
    let quantity: Int
    let onIncrement: () -> Void
    let onDecrement: () -> Void
    
    var body: some View {
        HStack(spacing: 0) {
            Button(action: onDecrement) {
                Image(systemName: "minus")
                    .font(.caption2.weight(.bold))
                    .foregroundColor(.white)
                    .frame(width: 24, height: 26)
            }
            .buttonStyle(.plain)
            
            Text("\(quantity)")
                .font(.caption.weight(.bold))
                .foregroundColor(.white)
                .frame(minWidth: 16)
                .multilineTextAlignment(.center)
            
            Button(action: onIncrement) {
                Image(systemName: "plus")
                    .font(.caption2.weight(.bold))
                    .foregroundColor(.white)
                    .frame(width: 24, height: 26)
            }
            .buttonStyle(.plain)
        }
        .background(AppTheme.Colors.primary)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.Spacing.smallCornerRadius))
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.Spacing.smallCornerRadius)
                .stroke(AppTheme.Colors.primary, lineWidth: 1)
        )
    }
}

struct SpacesHeaderView: View {
    var viewModel: AppViewModel
    @Binding var showingSpaceSelectionSheet: Bool
    
    var body: some View {
        @Bindable var viewModel = viewModel
        HStack {
            Toggle("Shopping Spaces", isOn: Binding(
                get: { viewModel.isSpacesEnabled },
                set: { newValue in
                    withAnimation {
                        viewModel.isSpacesEnabled = newValue
                        if newValue {
                            showingSpaceSelectionSheet = true
                        }
                    }
                }
            ))
            .toggleStyle(SwitchToggleStyle(tint: AppTheme.Colors.primary))
            .font(.headline)
            .foregroundColor(AppTheme.Colors.textPrimary)
        }
        .padding(.horizontal, AppTheme.Spacing.medium)
        .padding(.vertical, 8)
    }
}


struct SpaceSelectionSheet: View {
    @Environment(\.dismiss) var dismiss
    var viewModel: AppViewModel
    @Binding var showingCreateSpace: Bool
    
    var body: some View {
        NavigationStack {
            List {
                ForEach(viewModel.carts) { cart in
                    Button(action: {
                        withAnimation {
                            viewModel.selectedCartId = cart.id
                        }
                        dismiss()
                    }) {
                        HStack(spacing: AppTheme.Spacing.medium) {
                            Image(systemName: "cart.fill")
                                .foregroundColor(viewModel.selectedCartId == cart.id ? AppTheme.Colors.primary : AppTheme.Colors.textSecondary)
                                .imageScale(.large)
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text(cart.name)
                                    .font(.headline)
                                    .foregroundColor(AppTheme.Colors.textPrimary)
                                Text("\(cart.items.count) items")
                                    .font(.subheadline)
                                    .foregroundColor(AppTheme.Colors.textSecondary)
                            }
                            
                            Spacer()
                            
                            if viewModel.selectedCartId == cart.id {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(AppTheme.Colors.primary)
                                    .font(.title3)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                    .buttonStyle(.plain)
                }
                
                Button(action: {
                    dismiss()
                    // Delay slightly to allow the sheet dismiss animation to finish before showing the alert
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        showingCreateSpace = true
                    }
                }) {
                    HStack(spacing: AppTheme.Spacing.medium) {
                        Image(systemName: "plus.circle.fill")
                            .foregroundColor(AppTheme.Colors.primary)
                            .imageScale(.large)
                        
                        Text("Create New Space")
                            .font(.headline)
                            .foregroundColor(AppTheme.Colors.primary)
                    }
                    .padding(.vertical, 4)
                }
            }
            .navigationTitle("Select Space")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Close") {
                        dismiss()
                    }
                }
            }
        }
    }
}


#Preview {
    ContentView()
}
