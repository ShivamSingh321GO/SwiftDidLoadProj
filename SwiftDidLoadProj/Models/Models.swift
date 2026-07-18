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
    let image: String
    
    // New fields from JSON
    let brand: String?
    let category: String?
    let subCategory: String?
    let rating: Double?
    let ratingCount: String?
    let aliases: [String]?
    
    // Sharing History Fields
    var addedByUserId: String? = nil
    var addedByUserName: String? = nil
    
    init(id: String = UUID().uuidString,
         name: String,
         price: Int,
         originalPrice: Int? = nil,
         weight: String,
         discount: String? = nil,
         imageURL: URL? = nil,
         image: String = "",
         brand: String? = nil,
         category: String? = nil,
         subCategory: String? = nil,
         rating: Double? = nil,
         ratingCount: String? = nil,
         aliases: [String]? = nil,
         addedByUserId: String? = nil,
         addedByUserName: String? = nil) {
        self.id = id
        self.name = name
        self.price = price
        self.originalPrice = originalPrice
        self.weight = weight
        self.discount = discount
        self.imageURL = imageURL
        self.image = image
        self.brand = brand
        self.category = category
        self.subCategory = subCategory
        self.rating = rating
        self.ratingCount = ratingCount
        self.aliases = aliases
        self.addedByUserId = addedByUserId
        self.addedByUserName = addedByUserName
    }
}

struct Cart: Identifiable, Hashable {
    var id = UUID()
    var name: String
    var items: [Item] = []
    var createdBy: String? = nil
}

struct Profile: Codable, Hashable {
    let id: String
    let email: String
    let displayName: String?
    let phone: String?
}

struct UserSession: Codable, Hashable {
    let accessToken: String
    let userId: String
    let email: String
    let phone: String?
    let displayName: String?
}
