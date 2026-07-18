import Foundation

struct OFFSearchResponse: Codable {
    let count: Int
    let page: Int
    let products: [OFFProduct]
}

struct OFFProduct: Codable {
    let id: String
    let productName: String?
    let imageFrontSmallUrl: String?
    let quantity: String?
    let brands: String?
    
    enum CodingKeys: String, CodingKey {
        case id = "id"
        case productName = "product_name"
        case imageFrontSmallUrl = "image_front_small_url"
        case quantity = "quantity"
        case brands = "brands"
    }
}

class APIService {
    static let shared = APIService()
    
    private init() {}
    
    func fetchGroceries() async throws -> [OFFProduct] {
        // Query Open Food Facts for groceries. 
        let urlString = "https://world.openfoodfacts.org/api/v2/search?categories_tags_en=groceries&fields=id,product_name,image_front_small_url,quantity,brands&json=true&page_size=30"
        
        guard let url = URL(string: urlString) else {
            throw URLError(.badURL)
        }
        
        let (data, response) = try await URLSession.shared.data(from: url)
        
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }
        
        let decodedResponse = try JSONDecoder().decode(OFFSearchResponse.self, from: data)
        return decodedResponse.products
    }
}
