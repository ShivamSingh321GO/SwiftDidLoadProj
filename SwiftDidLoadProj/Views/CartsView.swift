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

struct MoveItemContext: Identifiable {
    let id = UUID()
    let item: Item
    let quantity: Int
}

struct CartDetailView: View {
    let cartId: UUID
    @Environment(AppViewModel.self) var viewModel
    
    @State private var selectedDonation: Int = 0
    @State private var showingCustomDonationAlert = false
    @State private var customDonationText = ""
    @State private var showingShareSheet = false
    @State private var showingHistorySheet = false
    @State private var showingScannerSheet = false
    @State private var itemToMove: MoveItemContext? = nil
    
    private var cart: Cart? {
        viewModel.carts.first { $0.id == cartId }
    }
    
    private var isCartOwner: Bool {
        guard let cart = cart else { return true }
        guard let session = viewModel.currentUserSession else { return true }
        guard let createdBy = cart.createdBy else { return true }
        return createdBy == session.userId
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
        .sheet(isPresented: $showingShareSheet) {
            ShareCartSheet(cartId: cartId, viewModel: viewModel)
        }
        .sheet(isPresented: $showingHistorySheet) {
            if let cart = cart {
                CartHistorySheet(cart: cart)
            }
        }
        .sheet(isPresented: $showingScannerSheet) {
            HandwritingScanView(cartId: cartId)
                .environment(viewModel)
        .sheet(item: $itemToMove) { context in
            MoveToCartSheet(
                item: context.item,
                quantity: context.quantity,
                currentCartId: cartId,
                viewModel: viewModel
            )
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
        }
        .toolbar {
            if let cart = cart {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        if viewModel.selectedCartId != cart.id {
                            Button(action: {
                                withAnimation {
                                    viewModel.selectedCartId = cart.id
                                }
                            }) {
                                Label("Make Active", systemImage: "checkmark.circle")
                            }
                        } else {
                            Button(action: {}) {
                                Label("Active Cart", systemImage: "checkmark.circle.fill")
                            }
                            .disabled(true)
                        }
                        
                        if viewModel.isSpacesEnabled && isCartOwner {
                            Button(action: {
                                showingShareSheet = true
                            }) {
                                Label("Share Cart", systemImage: "person.badge.plus")
                            }
                        }

                        // ✨ Always visible — Scan List
                        Button(action: {
                            showingScannerSheet = true
                        }) {
                            Label("Scan List", systemImage: "doc.text.viewfinder")
                        }

                        if viewModel.isSpacesEnabled {
                            Button(action: {
                                showingHistorySheet = true
                            }) {
                                Label("Cart History", systemImage: "clock.arrow.circlepath")
                            }
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                            .font(.title2)
                            .foregroundColor(AppTheme.Colors.textPrimary)
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
                        
                        if !item.image.isEmpty {
                            Image(item.image)
                                .resizable()
                                .scaledToFit()
                                .padding(4)
                        } else if let url = item.imageURL {
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
                                itemToMove = MoveItemContext(item: item, quantity: quantity)
                            }) {
                                Label("Move to cart", systemImage: "arrow.right.circle")
                                    .font(.caption2)
                                    .foregroundColor(AppTheme.Colors.primary)
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
                if isCartOwner {
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
                } else {
                    HStack {
                        Image(systemName: "lock.shield.fill")
                            .foregroundColor(.orange)
                        Text("Only the creator of this cart can place orders")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(AppTheme.Colors.textSecondary)
                        Spacer()
                    }
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color.orange.opacity(0.08))
                    .cornerRadius(12)
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 12)
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

struct ShareCartSheet: View {
    let cartId: UUID
    var viewModel: AppViewModel
    @Environment(\.dismiss) var dismiss
    
    @State private var email = ""
    @State private var isLoading = false
    @State private var errorMessage: String? = nil
    @State private var successMessage: String? = nil
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                VStack(spacing: 8) {
                    Image(systemName: "person.badge.plus.fill")
                        .font(.system(size: 48))
                        .foregroundColor(AppTheme.Colors.primary)
                        .padding(.top, 24)
                    
                    Text("Share Shopping Space")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Text("Enter the email address of the user you want to invite to this cart. They will be able to view and add items to it.")
                        .font(.subheadline)
                        .foregroundColor(AppTheme.Colors.textSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)
                }
                
                if let errorMessage = errorMessage {
                    Text(errorMessage)
                        .font(.subheadline)
                        .foregroundColor(.red)
                        .padding(.horizontal, 24)
                }
                
                if let successMessage = successMessage {
                    Text(successMessage)
                        .font(.subheadline)
                        .foregroundColor(.green)
                        .padding(.horizontal, 24)
                }
                
                VStack(alignment: .leading, spacing: 6) {
                    Text("User's Email")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(AppTheme.Colors.textSecondary)
                    
                    TextField("user@example.com", text: $email)
                        .keyboardType(.emailAddress)
                        .autocapitalization(.none)
                        .autocorrectionDisabled()
                }
                .padding(.all, 12)
                .background(Color(.secondarySystemBackground))
                .cornerRadius(12)
                .padding(.horizontal, 24)
                
                Spacer()
                
                Button(action: {
                    Task {
                        await performShare()
                    }
                }) {
                    ZStack {
                        if isLoading {
                            ProgressView()
                                .tint(.white)
                        } else {
                            Text("Send Invite")
                                .font(.headline)
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                        }
                    }
                    .frame(maxWidth: .infinity, minHeight: 50)
                    .background(email.isEmpty ? AppTheme.Colors.primary.opacity(0.6) : AppTheme.Colors.primary)
                    .cornerRadius(14)
                }
                .disabled(email.isEmpty || isLoading)
                .padding(.horizontal, 24)
                .padding(.bottom, 24)
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(AppTheme.Colors.textSecondary)
                }
            }
        }
    }
    
    private func performShare() async {
        isLoading = true
        errorMessage = nil
        successMessage = nil
        
        do {
            try await viewModel.shareCart(cartId: cartId, email: email)
            isLoading = false
            successMessage = "Cart shared successfully!"
            try? await Task.sleep(nanoseconds: 1_000_000_000)
            dismiss()
        } catch {
            isLoading = false
            errorMessage = error.localizedDescription
        }
    }
}

struct CartHistorySheet: View {
    let cart: Cart
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationStack {
            List {
                if cart.items.isEmpty {
                    Text("No items added yet.")
                        .foregroundColor(AppTheme.Colors.textSecondary)
                } else {
                    ForEach(Array(cart.items.enumerated()), id: \.offset) { index, item in
                        HStack(spacing: 12) {
                            // Mini Thumbnail
                            if !item.image.isEmpty {
                                Image(item.image)
                                    .resizable()
                                    .frame(width: 40, height: 40)
                                    .cornerRadius(8)
                            } else {
                                CachedAsyncImage(url: item.imageURL) { img in
                                    img
                                        .resizable()
                                        .aspectRatio(contentMode: .fill)
                                } placeholder: {
                                    ProgressView()
                                }
                                .frame(width: 40, height: 40)
                                .cornerRadius(8)
                            }
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text(item.name)
                                    .font(.headline)
                                    .foregroundColor(AppTheme.Colors.textPrimary)
                                
                                HStack(spacing: 4) {
                                    Image(systemName: "person.circle.fill")
                                        .font(.caption)
                                        .foregroundColor(AppTheme.Colors.primary)
                                    Text("Added by \(item.addedByUserName ?? "Owner")")
                                        .font(.caption)
                                        .foregroundColor(AppTheme.Colors.textSecondary)
                                }
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
            .navigationTitle("Cart History")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Close") {
                        dismiss()
                    }
                    .foregroundColor(AppTheme.Colors.textSecondary)
                }
            }
        }
    }
}

#Preview {
    NavigationView {
        CartsView()
            .environment(AppViewModel())
    }
}

// MARK: - Move To Cart Sheet

struct MoveToCartSheet: View {
    let item: Item
    let quantity: Int
    let currentCartId: UUID
    var viewModel: AppViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var isCreatingNewSpace = false
    @State private var newSpaceName = ""

    private var otherCarts: [Cart] {
        viewModel.carts.filter { $0.id != currentCartId }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header Info
            VStack(alignment: .leading, spacing: 6) {
                Text("Move to Space")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(AppTheme.Colors.textPrimary)
                
                Text("Select a destination Shopping Space for this item")
                    .font(.subheadline)
                    .foregroundColor(AppTheme.Colors.textSecondary)
            }
            .padding(.horizontal, 24)
            .padding(.top, 24)
            .padding(.bottom, 12)

            // Item Preview Card
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(AppTheme.Colors.secondaryBackground)
                        .frame(width: 44, height: 44)
                    if !item.image.isEmpty {
                        Image(item.image)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 36, height: 36)
                    } else if let url = item.imageURL {
                        CachedAsyncImage(url: url) { img in
                            img.resizable().scaledToFit()
                        } placeholder: {
                            ProgressView()
                        }
                        .frame(width: 36, height: 36)
                    }
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(item.name)
                        .font(.subheadline)
                        .fontWeight(.bold)
                        .lineLimit(1)
                    Text("Qty: \(quantity)  ·  ₹\(item.price * quantity)")
                        .font(.caption)
                        .foregroundColor(AppTheme.Colors.textSecondary)
                }
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color(.secondarySystemBackground))
            .cornerRadius(12)
            .padding(.horizontal, 24)
            .padding(.bottom, 16)

            Divider()

            // Scrollable list of Spaces & Creation Form
            ScrollView {
                VStack(spacing: 12) {
                    // List of existing spaces
                    ForEach(otherCarts) { cart in
                        let isSelected = viewModel.selectedCartId == cart.id
                        
                        Button(action: {
                            viewModel.moveItems(
                                item: item,
                                quantity: quantity,
                                fromCartId: currentCartId,
                                toCartId: cart.id
                            )
                            dismiss()
                        }) {
                            HStack(spacing: 16) {
                                ZStack {
                                    Circle()
                                        .fill(isSelected ? AppTheme.Colors.primary.opacity(0.15) : Color(.systemGray6))
                                        .frame(width: 44, height: 44)
                                    
                                    Image(systemName: isSelected ? "cart.fill" : "cart")
                                        .foregroundColor(isSelected ? AppTheme.Colors.primary : AppTheme.Colors.textSecondary)
                                        .font(.system(size: 18, weight: .semibold))
                                }
                                
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(cart.name)
                                        .font(.headline)
                                        .foregroundColor(isSelected ? AppTheme.Colors.primary : AppTheme.Colors.textPrimary)
                                        .fontWeight(isSelected ? .bold : .semibold)
                                    
                                    Text("\(cart.items.count) items")
                                        .font(.caption)
                                        .foregroundColor(AppTheme.Colors.textSecondary)
                                }
                                
                                Spacer()
                                
                                Image(systemName: "arrow.right.circle.fill")
                                    .foregroundColor(AppTheme.Colors.primary)
                                    .font(.title3)
                            }
                            .padding(.all, 16)
                            .background(
                                RoundedRectangle(cornerRadius: 16)
                                    .fill(isSelected ? AppTheme.Colors.primary.opacity(0.04) : Color(.secondarySystemBackground))
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 16)
                                    .stroke(isSelected ? AppTheme.Colors.primary.opacity(0.3) : Color.clear, lineWidth: 1.5)
                            )
                        }
                        .buttonStyle(.plain)
                    }

                    // Create New Space Section
                    if isCreatingNewSpace {
                        VStack(spacing: 12) {
                            HStack(spacing: 12) {
                                Image(systemName: "pencil")
                                    .foregroundColor(AppTheme.Colors.primary)
                                    .font(.headline)
                                
                                TextField("Enter space name...", text: $newSpaceName)
                                    .font(.body)
                                    .foregroundColor(AppTheme.Colors.textPrimary)
                                    .textFieldStyle(.plain)
                            }
                            .padding(.all, 14)
                            .background(Color(.secondarySystemBackground))
                            .cornerRadius(12)
                            
                            HStack(spacing: 12) {
                                Button(action: {
                                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                        isCreatingNewSpace = false
                                        newSpaceName = ""
                                    }
                                }) {
                                    Text("Cancel")
                                        .font(.subheadline)
                                        .fontWeight(.semibold)
                                        .foregroundColor(AppTheme.Colors.textSecondary)
                                        .frame(maxWidth: .infinity, minHeight: 44)
                                        .background(Color(.systemGray6))
                                        .cornerRadius(12)
                                }
                                .buttonStyle(.plain)
                                
                                Button(action: {
                                    let trimmed = newSpaceName.trimmingCharacters(in: .whitespacesAndNewlines)
                                    if !trimmed.isEmpty {
                                        // 1. Create the new cart
                                        viewModel.createCart(name: trimmed, makeActive: false)
                                        
                                        // 2. Locate the new cart's UUID
                                        if let newCart = viewModel.carts.first(where: { $0.name == trimmed }) {
                                            // 3. Move items directly to it
                                            viewModel.moveItems(
                                                item: item,
                                                quantity: quantity,
                                                fromCartId: currentCartId,
                                                toCartId: newCart.id
                                            )
                                        }
                                        newSpaceName = ""
                                        isCreatingNewSpace = false
                                        dismiss()
                                    }
                                }) {
                                    Text("Create & Move")
                                        .font(.subheadline)
                                        .fontWeight(.semibold)
                                        .foregroundColor(.white)
                                        .frame(maxWidth: .infinity, minHeight: 44)
                                        .background(newSpaceName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? AppTheme.Colors.primary.opacity(0.5) : AppTheme.Colors.primary)
                                        .cornerRadius(12)
                                }
                                .buttonStyle(.plain)
                                .disabled(newSpaceName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                            }
                        }
                        .padding(.all, 16)
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(Color(.systemBackground))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(AppTheme.Colors.primary.opacity(0.3), lineWidth: 1.5)
                        )
                        .transition(.asymmetric(insertion: .move(edge: .bottom).combined(with: .opacity), removal: .opacity))
                    } else {
                        // Create New Space Button matching the dash design of home screen
                        Button(action: {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                isCreatingNewSpace = true
                            }
                        }) {
                            HStack(spacing: 16) {
                                ZStack {
                                    Circle()
                                        .fill(AppTheme.Colors.primary.opacity(0.1))
                                        .frame(width: 44, height: 44)
                                    
                                    Image(systemName: "plus")
                                        .foregroundColor(AppTheme.Colors.primary)
                                        .font(.system(size: 18, weight: .bold))
                                }
                                
                                Text("Create New Space")
                                    .font(.headline)
                                    .foregroundColor(AppTheme.Colors.primary)
                                
                                Spacer()
                                
                                Image(systemName: "chevron.right")
                                    .foregroundColor(AppTheme.Colors.primary.opacity(0.7))
                                    .font(.system(size: 14, weight: .bold))
                                
                            }
                            .padding(.all, 16)
                            .background(
                                RoundedRectangle(cornerRadius: 16)
                                    .strokeBorder(
                                        AppTheme.Colors.primary.opacity(0.3),
                                        style: StrokeStyle(lineWidth: 1.5, lineCap: .round, lineJoin: .round, dash: [5, 4])
                                    )
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, 16)
                .padding(.bottom, 24)
            }
        }
        .background(Color(.systemBackground))
    }
}
