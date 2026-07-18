import Foundation
import SwiftUI
import Observation

struct Item: Identifiable, Hashable {
    let id: String
    let name: String
    let price: Int
    let originalPrice: Int?
    let weight: String
    let discount: String?
    let imageURL: URL?
    
    init(id: String = UUID().uuidString, name: String, price: Int, originalPrice: Int? = nil, weight: String, discount: String? = nil, imageURL: URL? = nil) {
        self.id = id
        self.name = name
        self.price = price
        self.originalPrice = originalPrice
        self.weight = weight
        self.discount = discount
        self.imageURL = imageURL
    }
}

struct Space: Identifiable, Hashable {
    let id = UUID()
    var name: String
    var items: [Item] = []
}

@Observable
class AppViewModel {
    var spaces: [Space] = [
        Space(name: "Home Groceries", items: [])
    ]
    var currentCart: [Item] = []
    
    var items: [Item] = []
    
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
    
    func addToCart(item: Item) {
        currentCart.append(item)
    }
    
    func createSpaceAndTransferCart(name: String) {
        guard !name.isEmpty else { return }
        let newSpace = Space(name: name, items: currentCart)
        spaces.append(newSpace)
        currentCart.removeAll()
    }
}
