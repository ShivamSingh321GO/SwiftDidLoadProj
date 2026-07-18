import Foundation
import SwiftUI
import Observation

struct Item: Identifiable, Hashable {
    let id = UUID()
    let name: String
    let price: Int
    let originalPrice: Int?
    let weight: String
    let discount: String?
    let imageName: String
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
    
    // Dummy Data
    static let sampleItems = [
        Item(name: "Maggi Masala - 2 Minutes Instant Noodles", price: 60, originalPrice: nil, weight: "300 g", discount: nil, imageName: "carrot"),
        Item(name: "Maggi 2 Minutes Instant Noodles Made With...", price: 79, originalPrice: 90, weight: "420 g", discount: "12% OFF on MRP", imageName: "carrot"),
        Item(name: "Maggi 2 - Minute Instant Noodles Mega Pack", price: 162, originalPrice: 180, weight: "900 g", discount: "10% OFF on MRP", imageName: "carrot"),
        Item(name: "Yippee Magic Masala Noodles", price: 56, originalPrice: 60, weight: "290.4 g", discount: "6% OFF on MRP", imageName: "carrot"),
        Item(name: "Maggi Veg Atta Noodles", price: 98, originalPrice: 108, weight: "290 g", discount: nil, imageName: "carrot")
    ]
    
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
