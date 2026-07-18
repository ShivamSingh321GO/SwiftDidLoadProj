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
    
    // New fields from JSON
    let brand: String?
    let category: String?
    let subCategory: String?
    let rating: Double?
    let ratingCount: String?
    let aliases: [String]?
    
    init(id: String = UUID().uuidString,
         name: String,
         price: Int,
         originalPrice: Int? = nil,
         weight: String,
         discount: String? = nil,
         imageURL: URL? = nil,
         brand: String? = nil,
         category: String? = nil,
         subCategory: String? = nil,
         rating: Double? = nil,
         ratingCount: String? = nil,
         aliases: [String]? = nil) {
        self.id = id
        self.name = name
        self.price = price
        self.originalPrice = originalPrice
        self.weight = weight
        self.discount = discount
        self.imageURL = imageURL
        self.brand = brand
        self.category = category
        self.subCategory = subCategory
        self.rating = rating
        self.ratingCount = ratingCount
        self.aliases = aliases
    }
}

struct Cart: Identifiable, Hashable {
    let id = UUID()
    var name: String
    var items: [Item] = []
}
