import Foundation
import SwiftUI

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

struct Cart: Identifiable, Hashable {
    let id = UUID()
    var name: String
    var items: [Item] = []
}
