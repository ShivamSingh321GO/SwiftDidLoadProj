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
    
    init() {
        let defaultCart = Cart(name: "General Cart", items: [])
        self.carts = [defaultCart]
        self.selectedCartId = defaultCart.id
    }
    
    @MainActor
    func fetchGroceries() async {
        do {
            let products = try await APIService.shared.fetchGroceries()
            self.items = products.map { product in
                // Generate a random price since OFF doesn't provide one
                let randomPrice = Int.random(in: 40...200)
                
                return Item(
                    id: product.id,
                    name: product.productName ?? "Unknown Product",
                    price: randomPrice,
                    weight: product.quantity ?? "N/A",
                    imageURL: URL(string: product.imageFrontSmallUrl ?? "")
                )
            }
        } catch {
            print("Failed to fetch groceries: \(error)")
        }
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
            carts[index].items.append(item)
        }
    }
    
    func removeFromCart(item: Item) {
        let targetCartId = isSpacesEnabled ? selectedCartId : (carts.first { $0.name == "General Cart" }?.id ?? selectedCartId)
        if let index = carts.firstIndex(where: { $0.id == targetCartId }) {
            if let itemIndex = carts[index].items.firstIndex(where: { $0.id == item.id }) {
                carts[index].items.remove(at: itemIndex)
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
    }
}
