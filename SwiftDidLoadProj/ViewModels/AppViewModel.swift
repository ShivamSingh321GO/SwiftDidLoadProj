import Foundation
import SwiftUI
import Observation

@Observable
class AppViewModel {
    var carts: [Cart]
    var selectedCartId: UUID
    var items: [Item] = []
    var isSpacesEnabled: Bool = false {
        didSet {
            if !isSpacesEnabled {
                // When spaces is disabled, automatically set the active selection to General Cart
                if let generalCart = carts.first(where: { $0.name == "General Cart" }) {
                    selectedCartId = generalCart.id
                } else if let firstCart = carts.first {
                    selectedCartId = firstCart.id
                }
            }
        }
    }
    
    // User Authentication state
    var currentUserSession: UserSession? = nil
    var isUserLoggedIn: Bool { currentUserSession != nil }
    
    init() {
        let defaultCart = Cart(name: "General Cart", items: [])
        self.carts = [defaultCart]
        self.selectedCartId = defaultCart.id
        
        // Restore session from UserDefaults if exists
        if let data = UserDefaults.standard.data(forKey: "user_session"),
           let session = try? JSONDecoder().decode(UserSession.self, from: data) {
            self.currentUserSession = session
            SupabaseService.shared.setSession(session)
            
            // Map the General Cart's ID deterministically to the user's UUID
            if let userUuid = UUID(uuidString: session.userId) {
                self.carts[0].id = userUuid
                self.selectedCartId = userUuid
            }
            
            // Sync spaces and carts on start in background
            Task {
                await self.syncRemoteSpacesOnStart()
            }
        }
    }
    
    @MainActor
    private func syncRemoteSpacesOnStart() async {
        do {
            let remoteCarts = try await SupabaseService.shared.fetchSpaces()
            if !remoteCarts.isEmpty {
                var updatedCarts = remoteCarts
                // Make sure the General Cart (which has ID = userUuid) is present
                if let session = currentUserSession, let userUuid = UUID(uuidString: session.userId) {
                    if !updatedCarts.contains(where: { $0.id == userUuid }) {
                        // Create it if it is missing in the remote list
                        try? await SupabaseService.shared.createSpace(id: userUuid, name: "General Cart")
                        let localGeneral = carts.first(where: { $0.id == userUuid }) ?? Cart(id: userUuid, name: "General Cart", items: [])
                        updatedCarts.insert(localGeneral, at: 0)
                        try? await SupabaseService.shared.syncCartItems(spaceId: userUuid, items: localGeneral.items)
                    }
                }
                self.carts = updatedCarts
                if let first = updatedCarts.first {
                    self.selectedCartId = first.id
                }
            }
        } catch {
            print("Failed to sync remote spaces on launch: \(error.localizedDescription)")
        }
    }
    
    @MainActor
    func fetchGroceries() async {
        self.items = AppViewModel.staticProducts
    }
    
    // MARK: - Authentication API Helpers
    
    @MainActor
    func loginUser(session: UserSession) async {
        self.currentUserSession = session
        SupabaseService.shared.setSession(session)
        
        // Save session to UserDefaults for auto-login
        if let data = try? JSONEncoder().encode(session) {
            UserDefaults.standard.set(data, forKey: "user_session")
        }
        
        // Map local "General Cart" to use the user's UUID as its ID
        if let generalIndex = carts.firstIndex(where: { $0.name == "General Cart" }),
           let userUuid = UUID(uuidString: session.userId) {
            carts[generalIndex].id = userUuid
            self.selectedCartId = userUuid
        }
        
        do {
            let remoteCarts = try await SupabaseService.shared.fetchSpaces()
            if !remoteCarts.isEmpty {
                var updatedCarts = remoteCarts
                if let userUuid = UUID(uuidString: session.userId) {
                    if !updatedCarts.contains(where: { $0.id == userUuid }) {
                        // Create General Cart space in cloud
                        try? await SupabaseService.shared.createSpace(id: userUuid, name: "General Cart")
                        let localGeneral = carts.first(where: { $0.id == userUuid }) ?? Cart(id: userUuid, name: "General Cart", items: [])
                        updatedCarts.insert(localGeneral, at: 0)
                        try? await SupabaseService.shared.syncCartItems(spaceId: userUuid, items: localGeneral.items)
                    }
                }
                self.carts = updatedCarts
                if let first = updatedCarts.first {
                    self.selectedCartId = first.id
                }
            } else {
                // Upload existing local spaces to cloud database
                for cart in carts {
                    try? await SupabaseService.shared.createSpace(id: cart.id, name: cart.name)
                    try? await SupabaseService.shared.syncCartItems(spaceId: cart.id, items: cart.items)
                }
            }
        } catch {
            print("Failed to fetch/sync spaces upon login: \(error.localizedDescription)")
        }
    }
    
    func logoutUser() {
        SupabaseService.shared.logOut()
        self.currentUserSession = nil
        UserDefaults.standard.removeObject(forKey: "user_session")
        
        let defaultCart = Cart(name: "General Cart", items: [])
        self.carts = [defaultCart]
        self.selectedCartId = defaultCart.id
        self.isSpacesEnabled = false
    }
    
    // MARK: - Business Logic
    
    var selectedCart: Cart? {
        if !isSpacesEnabled {
            return carts.first { $0.name == "General Cart" } ?? carts.first
        }
        return carts.first { $0.id == selectedCartId }
    }
    
    var activeCartItemsCount: Int {
        selectedCart?.items.count ?? 0
    }
    
    func quantityInCart(of item: Item) -> Int {
        let targetCartId = isSpacesEnabled ? selectedCartId : (carts.first { $0.name == "General Cart" }?.id ?? selectedCartId)
        guard let targetCart = carts.first(where: { $0.id == targetCartId }) else { return 0 }
        return targetCart.items.filter { $0.id == item.id }.count
    }
    
    func addToCart(item: Item) {
        let targetCartId = isSpacesEnabled ? selectedCartId : (carts.first { $0.name == "General Cart" }?.id ?? selectedCartId)
        if let index = carts.firstIndex(where: { $0.id == targetCartId }) {
            var itemWithUser = item
            itemWithUser.addedByUserId = currentUserSession?.userId
            itemWithUser.addedByUserName = currentUserSession?.displayName ?? currentUserSession?.email ?? "You"
            carts[index].items.append(itemWithUser)
            syncCartItemsToSupabase(cartId: targetCartId)
        }
    }

    /// Adds an item directly to a specific cart by ID (used by HandwritingScanView)
    func addItem(_ item: Item, toCart cartId: UUID) {
        if let index = carts.firstIndex(where: { $0.id == cartId }) {
            var itemWithUser = item
            itemWithUser.addedByUserId = currentUserSession?.userId
            itemWithUser.addedByUserName = currentUserSession?.displayName ?? currentUserSession?.email ?? "You"
            carts[index].items.append(itemWithUser)
            syncCartItemsToSupabase(cartId: cartId)
        }
    }

    
    func removeFromCart(item: Item) {
        let targetCartId = isSpacesEnabled ? selectedCartId : (carts.first { $0.name == "General Cart" }?.id ?? selectedCartId)
        if let index = carts.firstIndex(where: { $0.id == targetCartId }) {
            if let itemIndex = carts[index].items.firstIndex(where: { $0.id == item.id }) {
                carts[index].items.remove(at: itemIndex)
                syncCartItemsToSupabase(cartId: targetCartId)
            }
        }
    }
    
    func createCart(name: String, makeActive: Bool = false) {
        guard !name.isEmpty else { return }
        let newCart = Cart(name: name, items: [])
        carts.append(newCart)
        if makeActive {
            selectedCartId = newCart.id
        }
        
        if isUserLoggedIn {
            Task {
                try? await SupabaseService.shared.createSpace(id: newCart.id, name: newCart.name)
            }
        }
    }
    
    func shareCart(cartId: UUID, email: String) async throws {
        try await SupabaseService.shared.shareSpace(spaceId: cartId, withEmail: email)
    }
    
    private func syncCartItemsToSupabase(cartId: UUID) {
        if isUserLoggedIn, let cart = carts.first(where: { $0.id == cartId }) {
            Task {
                try? await SupabaseService.shared.syncCartItems(spaceId: cartId, items: cart.items)
            }
        }
    }
    
    static let staticProducts: [Item] = [
        Item(id: "1", name: "Amul Gold Full Cream Milk", price: 72, originalPrice: 74, weight: "1 L", discount: "3% OFF", image: "AmulFullCreame", brand: "Amul", category: "Dairy, Bread & Eggs", subCategory: "Milk", rating: 4.8, ratingCount: "14.8K", aliases: ["milk", "amul", "full cream milk"]),
        Item(id: "2", name: "Mother Dairy Paneer", price: 95, originalPrice: 110, weight: "200 g", discount: "14% OFF", image: "Panner", brand: "Mother Dairy", category: "Dairy, Bread & Eggs", subCategory: "Paneer", rating: 4.7, ratingCount: "12.1K", aliases: ["paneer", "mother dairy", "cottage cheese"]),
        Item(id: "3", name: "Britannia Brown Bread", price: 60, originalPrice: 65, weight: "400 g", discount: "8% OFF", image: "BreadPack", brand: "Britannia", category: "Dairy, Bread & Eggs", subCategory: "Bread", rating: 4.6, ratingCount: "9.5K", aliases: ["bread", "brown bread", "britannia"]),
        Item(id: "4", name: "Amul Salted Butter", price: 130, originalPrice: 140, weight: "200 g", discount: "7% OFF", image: "AmulButter", brand: "Amul", category: "Dairy, Bread & Eggs", subCategory: "Butter", rating: 4.9, ratingCount: "21.2K", aliases: ["butter", "amul butter", "salted butter"]),
        Item(id: "5", name: "Mother Dairy Classic Curd", price: 35, originalPrice: 40, weight: "400 g", discount: "13% OFF", image: "Dahi", brand: "Mother Dairy", category: "Dairy, Bread & Eggs", subCategory: "Curd", rating: 4.7, ratingCount: "8.2K", aliases: ["curd", "dahi", "mother dairy"]),
        Item(id: "6", name: "Farm Fresh White Eggs", price: 117, originalPrice: 125, weight: "10 pcs", discount: "6% OFF", image: "Eggs", brand: "Farm Fresh", category: "Dairy, Bread & Eggs", subCategory: "Eggs", rating: 4.8, ratingCount: "10.6K", aliases: ["eggs", "white eggs"]),
        Item(id: "7", name: "Coca-Cola", price: 110, originalPrice: 120, weight: "2 L", discount: "8% OFF", image: "Cocacola", brand: "Coca-Cola", category: "Cold Drinks & Juices", subCategory: "Soft Drink", rating: 4.8, ratingCount: "18.5K", aliases: ["coke", "cola", "soft drink"]),
        Item(id: "8", name: "Sprite", price: 105, originalPrice: 115, weight: "2 L", discount: "9% OFF", image: "Sprite", brand: "Sprite", category: "Cold Drinks & Juices", subCategory: "Soft Drink", rating: 4.7, ratingCount: "15.2K", aliases: ["sprite", "lemon drink"]),
        Item(id: "9", name: "Thums Up", price: 110, originalPrice: 120, weight: "2 L", discount: "8% OFF", image: "ThumbsUp", brand: "Thums Up", category: "Cold Drinks & Juices", subCategory: "Soft Drink", rating: 4.8, ratingCount: "14.4K", aliases: ["thums up", "cola"]),
        Item(id: "10", name: "Real Mixed Fruit Juice", price: 120, originalPrice: 135, weight: "1 L", discount: "11% OFF", image: "Real", brand: "Real", category: "Cold Drinks & Juices", subCategory: "Juice", rating: 4.6, ratingCount: "7.3K", aliases: ["juice", "real", "mixed fruit"]),
        Item(id: "11", name: "Lay's Classic Salted Chips", price: 20, originalPrice: 20, weight: "52 g", discount: nil, image: "Lays", brand: "Lay's", category: "Snacks & Munchies", subCategory: "Chips", rating: 4.8, ratingCount: "25.6K", aliases: ["chips", "lays", "snack"]),
        Item(id: "12", name: "Kurkure Masala Munch", price: 20, originalPrice: 20, weight: "90 g", discount: nil, image: "Kurkure", brand: "Kurkure", category: "Snacks & Munchies", subCategory: "Namkeen", rating: 4.7, ratingCount: "17.9K", aliases: ["kurkure", "namkeen"]),
        Item(id: "13", name: "Haldiram's Aloo Bhujia", price: 68, originalPrice: 75, weight: "200 g", discount: "9% OFF", image: "Aalo-bhujia", brand: "Haldiram's", category: "Snacks & Munchies", subCategory: "Namkeen", rating: 4.8, ratingCount: "13.7K", aliases: ["bhujia", "haldiram", "namkeen"]),
        Item(id: "14", name: "Maggi 2-Minute Noodles", price: 70, originalPrice: 75, weight: "280 g", discount: "7% OFF", image: "Maggi", brand: "Maggi", category: "Instant Food", subCategory: "Noodles", rating: 4.9, ratingCount: "32.4K", aliases: ["maggi", "noodles"]),
        Item(id: "15", name: "Heinz Tomato Ketchup", price: 77, originalPrice: 96, weight: "342 g", discount: "20% OFF", image: "Sauce", brand: "Heinz", category: "Sauces & Spreads", subCategory: "Ketchup", rating: 4.8, ratingCount: "19.0K", aliases: ["ketchup", "heinz", "tomato sauce"]),
        Item(id: "16", name: "Kissan Mixed Fruit Jam", price: 165, originalPrice: 180, weight: "500 g", discount: "8% OFF", image: "Kissan", brand: "Kissan", category: "Sauces & Spreads", subCategory: "Jam", rating: 4.7, ratingCount: "11.8K", aliases: ["jam", "mixed fruit jam"]),
        Item(id: "17", name: "Aashirvaad Whole Wheat Atta", price: 295, originalPrice: 325, weight: "5 kg", discount: "9% OFF", image: "Wheat", brand: "Aashirvaad", category: "Atta, Rice & Dal", subCategory: "Atta", rating: 4.9, ratingCount: "29.2K", aliases: ["atta", "wheat flour"]),
        Item(id: "18", name: "India Gate Basmati Rice", price: 499, originalPrice: 560, weight: "5 kg", discount: "11% OFF", image: "Rice", brand: "India Gate", category: "Atta, Rice & Dal", subCategory: "Rice", rating: 4.8, ratingCount: "18.7K", aliases: ["rice", "basmati"]),
        Item(id: "19", name: "Tata Sampann Toor Dal", price: 185, originalPrice: 210, weight: "1 kg", discount: "12% OFF", image: "Toor-Dal", brand: "Tata Sampann", category: "Atta, Rice & Dal", subCategory: "Dal", rating: 4.7, ratingCount: "12.5K", aliases: ["dal", "toor dal", "arhar"]),
        Item(id: "20", name: "Fortune Sunlite Refined Oil", price: 165, originalPrice: 180, weight: "1 L", discount: "8% OFF", image: "RefinedOil", brand: "Fortune", category: "Oil & Ghee", subCategory: "Cooking Oil", rating: 4.7, ratingCount: "15.9K", aliases: ["oil", "refined oil"]),
        Item(id: "21", name: "Cadbury Dairy Milk Silk", price: 175, originalPrice: 185, weight: "150 g", discount: "5% OFF", image: "Dairy-milk", brand: "Cadbury", category: "Chocolates", subCategory: "Chocolate", rating: 4.9, ratingCount: "20.3K", aliases: ["chocolate", "silk", "cadbury"]),
        Item(id: "22", name: "Surf Excel Easy Wash Detergent Powder", price: 225, originalPrice: 250, weight: "1 kg", discount: "10% OFF", image: "Detergent-Powder", brand: "Surf Excel", category: "Cleaning Supplies", subCategory: "Detergent", rating: 4.8, ratingCount: "16.4K", aliases: ["detergent", "surf excel"]),
        Item(id: "23", name: "Colgate Strong Teeth Toothpaste", price: 125, originalPrice: 140, weight: "200 g", discount: "11% OFF", image: "Colagate", brand: "Colgate", category: "Personal Care", subCategory: "Toothpaste", rating: 4.8, ratingCount: "18.8K", aliases: ["toothpaste", "colgate"]),
        Item(id: "24", name: "Dove Cream Beauty Bathing Bar", price: 55, originalPrice: 65, weight: "125 g", discount: "15% OFF", image: "Dove-bar", brand: "Dove", category: "Personal Care", subCategory: "Soap", rating: 4.8, ratingCount: "14.2K", aliases: ["soap", "dove"]),
        Item(id: "25", name: "Tata Salt", price: 30, originalPrice: 34, weight: "1 kg", discount: "12% OFF", image: "Salt", brand: "Tata", category: "Masala & Spices", subCategory: "Salt", rating: 4.9, ratingCount: "27.5K", aliases: ["salt", "tata salt"])
    ]
    
    // MARK: - Recipe to Blinkit Demo Data
    
    static let mockRecipe = Recipe(
        name: "Paneer Tikka Masala",
        ingredients: [
            RecipeIngredient(genericName: "Paneer", searchTerms: ["paneer"]),
            RecipeIngredient(genericName: "Curd", searchTerms: ["curd", "dahi"]),
            RecipeIngredient(genericName: "Oil or Butter", searchTerms: ["oil", "butter"]),
            RecipeIngredient(genericName: "Salt", searchTerms: ["salt"]),
            RecipeIngredient(genericName: "Masala / Spices", searchTerms: ["masala", "bhujia"]) // using bhujia to show we can match multiple items if needed for demo
        ]
    )
    
    func products(for ingredient: RecipeIngredient) -> [Item] {
        return AppViewModel.staticProducts.filter { product in
            // Return true if any search term is found in product aliases, name, or subCategory
            for term in ingredient.searchTerms {
                if product.name.lowercased().contains(term.lowercased()) { return true }
                if let category = product.category, category.lowercased().contains(term.lowercased()) { return true }
                if let sub = product.subCategory, sub.lowercased().contains(term.lowercased()) { return true }
                if let aliases = product.aliases, aliases.contains(where: { $0.lowercased().contains(term.lowercased()) }) { return true }
            }
            return false
        }
    }
}
