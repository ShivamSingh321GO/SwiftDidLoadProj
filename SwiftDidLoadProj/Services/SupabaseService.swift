import Foundation

enum SupabaseError: Error, LocalizedError {
    case invalidURL
    case badResponse(statusCode: Int, message: String)
    case decodingError
    case unknown
    
    var errorDescription: String? {
        switch self {
        case .invalidURL: return "Invalid URL configuration."
        case .badResponse(let code, let msg): return "API Error (\(code)): \(msg)"
        case .decodingError: return "Failed to process data from server."
        case .unknown: return "An unknown error occurred."
        }
    }
}

class SupabaseService {
    static let shared = SupabaseService()
    private init() {}
    
    private var session: UserSession?
    
    func setSession(_ session: UserSession?) {
        self.session = session
    }
    
    func getSession() -> UserSession? {
        return session
    }
    
    // MARK: - Headers Helpers
    
    private func defaultHeaders(authRequired: Bool = true) -> [String: String] {
        var headers = [
            "apikey": SupabaseConfig.anonKey,
            "Content-Type": "application/json",
            "Prefer": "return=representation"
        ]
        if authRequired, let token = session?.accessToken {
            headers["Authorization"] = "Bearer \(token)"
        } else {
            headers["Authorization"] = "Bearer \(SupabaseConfig.anonKey)"
        }
        return headers
    }
    
    // MARK: - Authentication
    
    func signUp(email: String, password: String) async throws -> UserSession {
        guard let url = URL(string: "\(SupabaseConfig.url)/auth/v1/signup") else {
            throw SupabaseError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.allHTTPHeaderFields = defaultHeaders(authRequired: false)
        
        let body: [String: Any] = [
            "email": email,
            "password": password
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        try handleStatus(response, data: data)
        
        let authResponse = try JSONDecoder().decode(SupabaseAuthResponse.self, from: data)
        let session = UserSession(
            accessToken: authResponse.access_token,
            userId: authResponse.user.id,
            email: authResponse.user.email ?? email,
            phone: authResponse.user.phone,
            displayName: nil
        )
        self.session = session
        
        // Also insert profile directly to public profiles table
        try? await createProfile(userId: session.userId, email: session.email, phone: session.phone ?? "", displayName: "")
        
        // Fetch current profile to load user details
        if let profile = try? await fetchProfile(userId: session.userId) {
            let updatedSession = UserSession(
                accessToken: session.accessToken,
                userId: session.userId,
                email: profile.email,
                phone: profile.phone,
                displayName: profile.displayName
            )
            self.session = updatedSession
            return updatedSession
        }
        
        return session
    }
    
    func logIn(email: String, password: String) async throws -> UserSession {
        guard let url = URL(string: "\(SupabaseConfig.url)/auth/v1/token?grant_type=password") else {
            throw SupabaseError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.allHTTPHeaderFields = defaultHeaders(authRequired: false)
        
        let body = ["email": email, "password": password]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        try handleStatus(response, data: data)
        
        let authResponse = try JSONDecoder().decode(SupabaseAuthResponse.self, from: data)
        
        let session = UserSession(
            accessToken: authResponse.access_token,
            userId: authResponse.user.id,
            email: authResponse.user.email ?? email,
            phone: authResponse.user.phone,
            displayName: nil
        )
        self.session = session
        
        // Fetch current profile to load user details
        if let profile = try? await fetchProfile(userId: session.userId) {
            let updatedSession = UserSession(
                accessToken: session.accessToken,
                userId: session.userId,
                email: profile.email,
                phone: profile.phone,
                displayName: profile.displayName
            )
            self.session = updatedSession
            return updatedSession
        } else {
            // Auto insert profile row since it was manually created on dashboard and is missing
            try? await createProfile(userId: session.userId, email: session.email, phone: session.phone ?? "", displayName: "")
        }
        
        return session
    }
    
    func logOut() {
        self.session = nil
    }
    
    // MARK: - Profiles Table Helpers
    
    private func createProfile(userId: String, email: String, phone: String, displayName: String) async throws {
        guard let url = URL(string: "\(SupabaseConfig.url)/rest/v1/profiles") else {
            throw SupabaseError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        var headers = defaultHeaders(authRequired: true)
        headers["Prefer"] = "resolution=merge-duplicates"
        request.allHTTPHeaderFields = headers
        
        let body: [String: Any] = [
            "id": userId,
            "email": email,
            "display_name": displayName,
            "phone": phone
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (_, response) = try await URLSession.shared.data(for: request)
        // Profiles might fail if trigger already exists, ignore conflicts.
        if let http = response as? HTTPURLResponse, http.statusCode >= 300 {
            print("Profile insert returned statusCode: \(http.statusCode)")
        }
    }
    
    func fetchProfile(userId: String) async throws -> Profile {
        guard let url = URL(string: "\(SupabaseConfig.url)/rest/v1/profiles?id=eq.\(userId)&select=*") else {
            throw SupabaseError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.allHTTPHeaderFields = defaultHeaders(authRequired: true)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        try handleStatus(response, data: data)
        
        let profiles = try JSONDecoder().decode([Profile].self, from: data)
        guard let profile = profiles.first else {
            throw SupabaseError.decodingError
        }
        return profile
    }
    
    // MARK: - Database sync: Carts (Shopping Spaces)
    
    func fetchSpaces() async throws -> [Cart] {
        guard session != nil else { return [] }
        guard let url = URL(string: "\(SupabaseConfig.url)/rest/v1/shopping_spaces?select=*") else {
            throw SupabaseError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.allHTTPHeaderFields = defaultHeaders(authRequired: true)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        try handleStatus(response, data: data)
        
        let dbSpaces = try JSONDecoder().decode([DBShoppingSpace].self, from: data)
        
        var carts: [Cart] = []
        for dbSpace in dbSpaces {
            if let uuid = UUID(uuidString: dbSpace.id) {
                // Fetch items for each space, fallback to empty array if query fails
                let items = (try? await fetchCartItems(spaceId: dbSpace.id)) ?? []
                let cart = Cart(id: uuid, name: dbSpace.name, items: items, createdBy: dbSpace.created_by)
                carts.append(cart)
            }
        }
        return carts
    }
    
    func createSpace(id: UUID, name: String) async throws {
        guard let session = session else { return }
        guard let url = URL(string: "\(SupabaseConfig.url)/rest/v1/shopping_spaces") else {
            throw SupabaseError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.allHTTPHeaderFields = defaultHeaders(authRequired: true)
        
        let body: [String: Any] = [
            "id": id.uuidString.lowercased(),
            "name": name,
            "created_by": session.userId
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        try handleStatus(response, data: data)
    }
    
    func deleteSpace(id: UUID) async throws {
        guard let url = URL(string: "\(SupabaseConfig.url)/rest/v1/shopping_spaces?id=eq.\(id.uuidString.lowercased())") else {
            throw SupabaseError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        request.allHTTPHeaderFields = defaultHeaders(authRequired: true)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        try handleStatus(response, data: data)
    }
    
    func shareSpace(spaceId: UUID, withEmail email: String) async throws {
        // 1. Fetch user ID from profiles table matching the email
        guard let fetchUrl = URL(string: "\(SupabaseConfig.url)/rest/v1/profiles?email=eq.\(email.trimmingCharacters(in: .whitespacesAndNewlines))&select=id") else {
            throw SupabaseError.invalidURL
        }
        
        var fetchRequest = URLRequest(url: fetchUrl)
        fetchRequest.httpMethod = "GET"
        fetchRequest.allHTTPHeaderFields = defaultHeaders(authRequired: true)
        
        let (data, response) = try await URLSession.shared.data(for: fetchRequest)
        try handleStatus(response, data: data)
        
        struct ProfileId: Decodable {
            let id: String
        }
        let profiles = try JSONDecoder().decode([ProfileId].self, from: data)
        guard let targetUserId = profiles.first?.id else {
            throw SupabaseError.badResponse(statusCode: 404, message: "User with email '\(email)' not found.")
        }
        
        // 2. Insert member row in space_members
        guard let insertUrl = URL(string: "\(SupabaseConfig.url)/rest/v1/space_members") else {
            throw SupabaseError.invalidURL
        }
        
        var insertRequest = URLRequest(url: insertUrl)
        insertRequest.httpMethod = "POST"
        insertRequest.allHTTPHeaderFields = defaultHeaders(authRequired: true)
        
        let body: [String: Any] = [
            "space_id": spaceId.uuidString.lowercased(),
            "user_id": targetUserId,
            "role": "member"
        ]
        insertRequest.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (insData, insRes) = try await URLSession.shared.data(for: insertRequest)
        try handleStatus(insRes, data: insData)
    }
    
    // MARK: - Database sync: Cart Items
    
    private func fetchCartItems(spaceId: String) async throws -> [Item] {
        guard let url = URL(string: "\(SupabaseConfig.url)/rest/v1/cart_items?space_id=eq.\(spaceId)&select=*,profiles:added_by(display_name,email)") else {
            throw SupabaseError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.allHTTPHeaderFields = defaultHeaders(authRequired: true)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        try handleStatus(response, data: data)
        
        let dbItems = try JSONDecoder().decode([DBCartItem].self, from: data)
        
        var items: [Item] = []
        for dbItem in dbItems {
            // Find base item from our 25 static items in the app
            // If item has a suffix like "-pack3", retrieve base item and apply pack index!
            let baseId = dbItem.item_id.components(separatedBy: "-pack").first ?? dbItem.item_id
            if var baseItem = AppViewModel.staticProducts.first(where: { $0.id == baseId }) {
                // If it is a multi-pack, construct virtual item
                if dbItem.item_id.contains("-pack3") {
                    baseItem = Item(
                        id: "\(baseItem.id)-pack3",
                        name: "\(baseItem.name) (3 packs)",
                        price: baseItem.price * 3 - 5,
                        originalPrice: baseItem.price * 3,
                        weight: "3 x \(baseItem.weight)",
                        discount: "5% OFF",
                        image: baseItem.image,
                        brand: baseItem.brand,
                        category: baseItem.category,
                        subCategory: baseItem.subCategory,
                        rating: baseItem.rating,
                        ratingCount: baseItem.ratingCount,
                        aliases: baseItem.aliases
                    )
                } else if dbItem.item_id.contains("-pack4") {
                    baseItem = Item(
                        id: "\(baseItem.id)-pack4",
                        name: "\(baseItem.name) (4 packs)",
                        price: baseItem.price * 4 - 10,
                        originalPrice: baseItem.price * 4,
                        weight: "4 x \(baseItem.weight)",
                        discount: "6% OFF",
                        image: baseItem.image,
                        brand: baseItem.brand,
                        category: baseItem.category,
                        subCategory: baseItem.subCategory,
                        rating: baseItem.rating,
                        ratingCount: baseItem.ratingCount,
                        aliases: baseItem.aliases
                    )
                }
                
                // Track who added this item
                baseItem.addedByUserId = dbItem.added_by
                baseItem.addedByUserName = dbItem.profiles?.display_name ?? dbItem.profiles?.email ?? "Unknown User"
                
                // Add the item multiple times according to its sync quantity
                for _ in 0..<dbItem.quantity {
                    items.append(baseItem)
                }
            }
        }
        return items
    }
    
    func syncCartItems(spaceId: UUID, items: [Item]) async throws {
        guard let session = session else { return }
        
        // 1. Delete existing items in the space
        guard let deleteUrl = URL(string: "\(SupabaseConfig.url)/rest/v1/cart_items?space_id=eq.\(spaceId.uuidString.lowercased())") else {
            throw SupabaseError.invalidURL
        }
        var deleteRequest = URLRequest(url: deleteUrl)
        deleteRequest.httpMethod = "DELETE"
        deleteRequest.allHTTPHeaderFields = defaultHeaders(authRequired: true)
        
        let (delData, delRes) = try await URLSession.shared.data(for: deleteRequest)
        try handleStatus(delRes, data: delData)
        
        // If cart has no items, stop here
        guard !items.isEmpty else { return }
        
        // 2. Count quantities of distinct items (group by item id & creator user ID)
        struct GroupKey: Hashable {
            let itemId: String
            let userId: String
        }
        let grouped = Dictionary(grouping: items) { item in
            GroupKey(itemId: item.id, userId: item.addedByUserId ?? session.userId)
        }
        
        let dbItems: [[String: Any]] = grouped.map { (key, list) in
            return [
                "space_id": spaceId.uuidString.lowercased(),
                "item_id": key.itemId,
                "quantity": list.count,
                "added_by": key.userId
            ]
        }
        
        // 3. Bulk insert items
        guard let insertUrl = URL(string: "\(SupabaseConfig.url)/rest/v1/cart_items") else {
            throw SupabaseError.invalidURL
        }
        var insertRequest = URLRequest(url: insertUrl)
        insertRequest.httpMethod = "POST"
        insertRequest.allHTTPHeaderFields = defaultHeaders(authRequired: true)
        insertRequest.httpBody = try JSONSerialization.data(withJSONObject: dbItems)
        
        let (insData, insRes) = try await URLSession.shared.data(for: insertRequest)
        try handleStatus(insRes, data: insData)
    }
    
    // MARK: - Utilities
    
    private func handleStatus(_ response: URLResponse, data: Data) throws {
        guard let http = response as? HTTPURLResponse else {
            throw SupabaseError.unknown
        }
        if http.statusCode >= 300 {
            var message = "Request failed"
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                message = json["message"] as? String ?? json["error_description"] as? String ?? message
            }
            throw SupabaseError.badResponse(statusCode: http.statusCode, message: message)
        }
    }
}

// MARK: - Helper decodable definitions

struct SupabaseAuthResponse: Decodable {
    let access_token: String
    let token_type: String
    let expires_in: Int
    let refresh_token: String?
    let user: SupabaseUser
}

struct SupabaseUser: Decodable {
    let id: String
    let email: String?
    let phone: String?
    let user_metadata: [String: AnyDecodable]?
}

struct DBShoppingSpace: Codable {
    let id: String
    let name: String
    let created_by: String
}

struct DBCartItem: Decodable {
    let space_id: String
    let item_id: String
    let quantity: Int
    let added_by: String
    let profiles: DBProfileResponse?
}

struct DBProfileResponse: Decodable {
    let display_name: String?
    let email: String?
}

enum AnyDecodable: Decodable {
    case string(String)
    case number(Double)
    case bool(Bool)
    case null
    
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let s = try? container.decode(String.self) {
            self = .string(s)
        } else if let d = try? container.decode(Double.self) {
            self = .number(d)
        } else if let b = try? container.decode(Bool.self) {
            self = .bool(b)
        } else {
            self = .null
        }
    }
    
    var stringValue: String? {
        switch self {
        case .string(let s): return s
        case .number(let n): return "\(n)"
        case .bool(let b): return b ? "true" : "false"
        case .null: return nil
        }
    }
}
