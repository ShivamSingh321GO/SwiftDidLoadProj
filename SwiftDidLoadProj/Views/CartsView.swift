import SwiftUI

struct CartsView: View {
    @Environment(AppViewModel.self) var viewModel
    @State private var showingCreateCart = false
    @State private var newCartName = ""
    
    var body: some View {
        List {
            ForEach(viewModel.carts) { cart in
                let isActive = viewModel.selectedCartId == cart.id
                
                NavigationLink(destination: CartDetailView(cartId: cart.id).environment(viewModel)) {
                    CartRowView(cart: cart, isActive: isActive)
                }
                .swipeActions(edge: .leading) {
                    if !isActive {
                        Button {
                            withAnimation {
                                viewModel.selectedCartId = cart.id
                            }
                        } label: {
                            Label("Set Active", systemImage: "checkmark.circle.fill")
                        }
                        .tint(AppTheme.Colors.primary)
                    }
                }
            }
        }
        .navigationTitle("Shopping Space")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: {
                    showingCreateCart = true
                }) {
                    Image(systemName: "plus")
                }
            }
        }
        .alert("Create New Space", isPresented: $showingCreateCart) {
            TextField("Space Name", text: $newCartName)
            Button("Cancel", role: .cancel) {
                newCartName = ""
            }
            Button("Create") {
                viewModel.createCart(name: newCartName)
                newCartName = ""
            }
        } message: {
            Text("Enter a name for your new space.")
        }
    }
}

struct CartDetailView: View {
    let cartId: UUID
    @Environment(AppViewModel.self) var viewModel
    
    @State private var selectedDonation: Int = 0
    @State private var showingCustomDonationAlert = false
    @State private var customDonationText = ""
    
    private var cart: Cart? {
        viewModel.carts.first { $0.id == cartId }
    }
    
    private var groupedItems: [(item: Item, quantity: Int)] {
        guard let cart = cart else { return [] }
        var counts: [String: Int] = [:]
        var uniqueItems: [Item] = []
        for item in cart.items {
            if let count = counts[item.id] {
                counts[item.id] = count + 1
            } else {
                counts[item.id] = 1
                uniqueItems.append(item)
            }
        }
        return uniqueItems.map { ($0, counts[$0.id] ?? 0) }
    }
    
    private var itemsTotal: Int {
        guard let cart = cart else { return 0 }
        return cart.items.reduce(0) { $0 + $1.price }
    }
    
    private var handlingCharge: Int {
        itemsTotal > 0 ? 5 : 0
    }
    
    private var grandTotal: Int {
        itemsTotal + handlingCharge + selectedDonation
    }
    
    private var mockedOriginalTotal: Int {
        Int(Double(itemsTotal) * 1.25)
    }
    
    private var totalSavings: Int {
        mockedOriginalTotal - itemsTotal + 30
    }
    
    var body: some View {
        Group {
            if let cart = cart {
                ZStack(alignment: .bottom) {
                    ScrollView {
                        VStack(spacing: AppTheme.Spacing.medium) {
                            spacesBannerView()
                            
                            if !cart.items.isEmpty {
                                deliveryHeaderView(itemCount: cart.items.count)
                                groupedItemsListView(cart: cart)
                                gstinCardView()
                                billDetailsCardView()
                                feedingIndiaCardView()
                            } else {
                                emptyStateView()
                            }
                            
                            Spacer().frame(height: 120)
                        }
                        .padding(.horizontal)
                        .padding(.top, AppTheme.Spacing.small)
                    }
                    .background(Color(.systemGroupedBackground))
                    
                    if !cart.items.isEmpty {
                        stickyCheckoutBar()
                    }
                }
                .navigationTitle(cart.name)
                .alert("Enter Custom Donation", isPresented: $showingCustomDonationAlert) {
                    TextField("Amount in ₹", text: $customDonationText)
                        .keyboardType(.numberPad)
                    Button("Cancel", role: .cancel) {
                        customDonationText = ""
                    }
                    Button("Add") {
                        if let amount = Int(customDonationText), amount > 0 {
                            selectedDonation = amount
                        }
                        customDonationText = ""
                    }
                } message: {
                    Text("Enter a custom amount you would like to donate to Feeding India.")
                }
            } else {
                Text("Cart not found")
                    .foregroundColor(AppTheme.Colors.textSecondary)
            }
        }
        .toolbar {
            if let cart = cart {
                ToolbarItem(placement: .topBarTrailing) {
                    if viewModel.selectedCartId != cart.id {
                        Button("Set Active") {
                            withAnimation {
                                viewModel.selectedCartId = cart.id
                            }
                        }
                    } else {
                        HStack(spacing: 4) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(AppTheme.Colors.primary)
                            Text("Active")
                                .font(.subheadline)
                                .foregroundColor(AppTheme.Colors.textSecondary)
                        }
                    }
                }
            }
        }
    }
    
    // MARK: - Subviews
    
    @ViewBuilder
    private func spacesBannerView() -> some View {
        if viewModel.isSpacesEnabled {
            NavigationLink(destination: CartsView().environment(viewModel)) {
                HStack {
                    Image(systemName: "square.stack.3d.up.fill")
                        .foregroundColor(AppTheme.Colors.primary)
                        .font(.title3)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Shopping Spaces")
                            .font(.subheadline)
                            .fontWeight(.bold)
                            .foregroundColor(AppTheme.Colors.textPrimary)
                        Text("Manage or switch to other shopping carts")
                            .font(.caption2)
                            .foregroundColor(AppTheme.Colors.textSecondary)
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundColor(AppTheme.Colors.textSecondary)
                }
                .padding()
                .background(Color(.systemBackground))
                .cornerRadius(AppTheme.Spacing.cornerRadius)
                .shadow(color: .black.opacity(0.04), radius: 4, y: 2)
            }
            .buttonStyle(.plain)
        }
    }
    
    @ViewBuilder
    private func deliveryHeaderView(itemCount: Int) -> some View {
        HStack(spacing: AppTheme.Spacing.small) {
            Image(systemName: "clock.fill")
                .foregroundColor(AppTheme.Colors.primary)
                .font(.title3)
            
            VStack(alignment: .leading, spacing: 2) {
                Text("Delivery in 14 minutes")
                    .font(.headline)
                    .fontWeight(.bold)
                Text("Shipment of \(itemCount) items")
                    .font(.caption)
                    .foregroundColor(AppTheme.Colors.textSecondary)
            }
            Spacer()
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(AppTheme.Spacing.cornerRadius)
        .shadow(color: .black.opacity(0.04), radius: 4, y: 2)
    }
    
    @ViewBuilder
    private func groupedItemsListView(cart: Cart) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(groupedItems, id: \.item.id) { grouped in
                let item = grouped.item
                let quantity = grouped.quantity
                
                HStack(alignment: .top, spacing: AppTheme.Spacing.small) {
                    ZStack {
                        RoundedRectangle(cornerRadius: AppTheme.Spacing.smallCornerRadius)
                            .fill(AppTheme.Colors.secondaryBackground)
                        
                        if let url = item.imageURL {
                            CachedAsyncImage(url: url) { image in
                                image
                                    .resizable()
                                    .scaledToFit()
                            } placeholder: {
                                ProgressView()
                            }
                            .padding(4)
                        }
                    }
                    .frame(width: 50, height: 50)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text(item.name)
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .lineLimit(2)
                            .multilineTextAlignment(.leading)
                        
                        Text(item.weight)
                            .font(.caption2)
                            .foregroundColor(AppTheme.Colors.textSecondary)
                        
                        Button(action: {
                            for _ in 0..<quantity {
                                viewModel.removeFromCart(item: item)
                            }
                        }) {
                            Text("Move to wishlist")
                                .font(.caption2)
                                .foregroundColor(AppTheme.Colors.textSecondary)
                                .underline()
                        }
                        .buttonStyle(.plain)
                    }
                    
                    Spacer()
                    
                    VStack(alignment: .trailing, spacing: AppTheme.Spacing.small) {
                        HStack(spacing: 0) {
                            Button(action: {
                                viewModel.removeFromCart(item: item)
                            }) {
                                Image(systemName: "minus")
                                    .font(.caption2.weight(.bold))
                                    .foregroundColor(.white)
                                    .frame(width: 22, height: 24)
                            }
                            .buttonStyle(.plain)
                            
                            Text("\(quantity)")
                                .font(.caption.weight(.bold))
                                .foregroundColor(.white)
                                .frame(minWidth: 14)
                                .multilineTextAlignment(.center)
                            
                            Button(action: {
                                viewModel.addToCart(item: item)
                            }) {
                                Image(systemName: "plus")
                                    .font(.caption2.weight(.bold))
                                    .foregroundColor(.white)
                                    .frame(width: 22, height: 24)
                            }
                            .buttonStyle(.plain)
                        }
                        .background(AppTheme.Colors.primary)
                        .clipShape(RoundedRectangle(cornerRadius: AppTheme.Spacing.smallCornerRadius))
                        
                        Text("₹\(item.price * quantity)")
                            .font(.subheadline)
                            .fontWeight(.bold)
                    }
                }
                .padding(.vertical, AppTheme.Spacing.medium)
                
                if item.id != groupedItems.last?.item.id {
                    Divider()
                }
            }
        }
        .padding(.horizontal)
        .background(Color(.systemBackground))
        .cornerRadius(AppTheme.Spacing.cornerRadius)
        .shadow(color: .black.opacity(0.04), radius: 4, y: 2)
    }
    
    @ViewBuilder
    private func gstinCardView() -> some View {
        HStack {
            Image(systemName: "percent.circle.fill")
                .foregroundColor(.blue)
                .font(.title3)
            VStack(alignment: .leading, spacing: 2) {
                Text("Add GSTIN details")
                    .font(.subheadline)
                    .fontWeight(.bold)
                Text("Claim GST input credit up to 18% on your order")
                    .font(.caption2)
                    .foregroundColor(AppTheme.Colors.textSecondary)
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundColor(AppTheme.Colors.textSecondary)
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(AppTheme.Spacing.cornerRadius)
        .shadow(color: .black.opacity(0.04), radius: 4, y: 2)
    }
    
    @ViewBuilder
    private func billDetailsCardView() -> some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.small) {
            Text("Bill details")
                .font(.headline)
                .fontWeight(.bold)
                .padding(.bottom, AppTheme.Spacing.extraSmall)
            
            HStack {
                Text("Items total")
                    .font(.subheadline)
                    .foregroundColor(AppTheme.Colors.textSecondary)
                Spacer()
                HStack(spacing: AppTheme.Spacing.extraSmall) {
                    Text("₹\(mockedOriginalTotal)")
                        .font(.caption)
                        .foregroundColor(AppTheme.Colors.textSecondary)
                        .strikethrough()
                    Text("₹\(itemsTotal)")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                }
            }
            
            HStack {
                Text("Handling charge")
                    .font(.subheadline)
                    .foregroundColor(AppTheme.Colors.textSecondary)
                Spacer()
                Text("₹\(handlingCharge)")
                    .font(.subheadline)
            }
            
            HStack {
                Text("Delivery charge")
                    .font(.subheadline)
                    .foregroundColor(AppTheme.Colors.textSecondary)
                Spacer()
                HStack(spacing: AppTheme.Spacing.extraSmall) {
                    Text("₹30")
                        .font(.caption)
                        .foregroundColor(AppTheme.Colors.textSecondary)
                        .strikethrough()
                    Text("FREE")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(AppTheme.Colors.primary)
                }
            }
            
            if selectedDonation > 0 {
                HStack {
                    Text("Feeding India donation")
                        .font(.subheadline)
                        .foregroundColor(AppTheme.Colors.textSecondary)
                    Spacer()
                    Text("₹\(selectedDonation)")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                }
            }
            
            Divider()
                .padding(.vertical, 4)
            
            HStack {
                Text("Grand total")
                    .font(.headline)
                    .fontWeight(.bold)
                Spacer()
                Text("₹\(grandTotal)")
                    .font(.headline)
                    .fontWeight(.bold)
            }
            
            HStack {
                Spacer()
                Text("Your total savings ₹\(totalSavings)")
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundColor(.blue)
                Spacer()
            }
            .padding(.vertical, 8)
            .background(Color.blue.opacity(0.1))
            .cornerRadius(6)
            .padding(.top, 4)
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(AppTheme.Spacing.cornerRadius)
        .shadow(color: .black.opacity(0.04), radius: 4, y: 2)
    }
    
    @ViewBuilder
    private func feedingIndiaCardView() -> some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.small) {
            HStack {
                Image(systemName: "heart.fill")
                    .foregroundColor(.red)
                Text("Join us at feeding india")
                    .font(.subheadline)
                    .fontWeight(.bold)
                Spacer()
            }
            
            Text("Together, we can fuel young minds to grow, learn, and thrive")
                .font(.caption)
                .foregroundColor(AppTheme.Colors.textSecondary)
            
            HStack(spacing: 8) {
                donationButton(amount: 5, label: "₹5")
                donationButton(amount: 10, label: "₹10")
                donationButton(amount: 15, label: "₹15")
                
                let isCustomActive = selectedDonation > 0 && selectedDonation != 5 && selectedDonation != 10 && selectedDonation != 15
                Button(action: {
                    showingCustomDonationAlert = true
                }) {
                    Text(isCustomActive ? "₹\(selectedDonation)" : "Custom")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(isCustomActive ? AppTheme.Colors.primary : AppTheme.Colors.textPrimary)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(isCustomActive ? AppTheme.Colors.primary.opacity(0.1) : Color(.systemGray6))
                        .cornerRadius(8)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(isCustomActive ? AppTheme.Colors.primary : Color(.systemGray4), lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)
            }
            .padding(.top, 4)
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(AppTheme.Spacing.cornerRadius)
        .shadow(color: .black.opacity(0.04), radius: 4, y: 2)
    }
    
    @ViewBuilder
    private func emptyStateView() -> some View {
        VStack(spacing: AppTheme.Spacing.medium) {
            Spacer().frame(height: 100)
            Image(systemName: "cart.badge.questionmark")
                .font(.system(size: 64))
                .foregroundColor(AppTheme.Colors.textSecondary)
            Text("No items in this space yet.")
                .font(.headline)
                .foregroundColor(AppTheme.Colors.textSecondary)
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }
    
    @ViewBuilder
    private func stickyCheckoutBar() -> some View {
        VStack(spacing: 0) {
            Divider()
            HStack {
                Button(action: {}) {
                    HStack {
                        Text("Select address at next step")
                            .font(.headline)
                            .fontWeight(.bold)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .fontWeight(.bold)
                    }
                    .foregroundColor(.white)
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(AppTheme.Colors.primary)
                    .cornerRadius(12)
                }
                .padding(.horizontal)
                .padding(.vertical, 12)
            }
            .background(Color(.systemBackground))
        }
    }
    
    private func donationButton(amount: Int, label: String) -> some View {
        let isSelected = selectedDonation == amount
        return Button(action: {
            withAnimation {
                selectedDonation = isSelected ? 0 : amount
            }
        }) {
            Text(label)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(isSelected ? AppTheme.Colors.primary : AppTheme.Colors.textPrimary)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(isSelected ? AppTheme.Colors.primary.opacity(0.1) : Color(.systemGray6))
                .cornerRadius(8)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(isSelected ? AppTheme.Colors.primary : Color(.systemGray4), lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }
}

struct CartRowView: View {
    let cart: Cart
    let isActive: Bool
    
    var body: some View {
        HStack(spacing: AppTheme.Spacing.medium) {
            Image(systemName: "cart.fill")
                .foregroundColor(AppTheme.Colors.primary)
                .imageScale(.large)
            
            VStack(alignment: .leading, spacing: AppTheme.Spacing.extraSmall) {
                HStack {
                    Text(cart.name)
                        .font(.headline)
                        .foregroundColor(AppTheme.Colors.textPrimary)
                    
                    if isActive {
                        Text("Active")
                            .font(.caption2)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(AppTheme.Colors.primary, in: RoundedRectangle(cornerRadius: 4))
                    }
                }
                
                Text("\(cart.items.count) items")
                    .font(.subheadline)
                    .foregroundColor(AppTheme.Colors.textSecondary)
            }
        }
        .padding(.vertical, AppTheme.Spacing.small)
    }
}


#Preview {
    NavigationView {
        CartsView()
            .environment(AppViewModel())
    }
}
