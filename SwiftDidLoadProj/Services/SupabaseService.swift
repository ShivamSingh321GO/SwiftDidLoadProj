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
        if authRequired, let token = session?.accessToken, !token.isEmpty {
            headers["Authorization"] = "Bearer \(token)"
        } else {
            headers["Authorization"] = "Bearer \(SupabaseConfig.anonKey)"
        }
        return headers
    }
    
    // MARK: - Core Request Executor with 5s Timeout and 401 JWT Retry
    
    private func performDataTask(for request: URLRequest, authRequired: Bool = true) async throws -> Data {
        var req = request
        req.timeoutInterval = 5 // 5 second max timeout per request
        
        let (data, response) = try await URLSession.shared.data(for: req)
        
        if let http = response as? HTTPURLResponse {
            if http.statusCode == 401 {
                // If token is expired (401 JWT expired), retry with anon key fallback
                var retryHeaders = defaultHeaders(authRequired: false)
                for (k, v) in req.allHTTPHeaderFields ?? [:] where k != "Authorization" && k != "apikey" {
                    retryHeaders[k] = v
                }
                req.allHTTPHeaderFields = retryHeaders
                
                let (retryData, retryResponse) = try await URLSession.shared.data(for: req)
                if let retryHttp = retryResponse as? HTTPURLResponse {
                    if retryHttp.statusCode < 300 {
                        return retryData
                    }
                    try handleStatus(retryHttp, data: retryData)
                }
            }
            try handleStatus(http, data: data)
            return data
        }
        
        throw SupabaseError.unknown
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
        
        let data = try await performDataTask(for: request, authRequired: false)
        
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
        
        let data = try await performDataTask(for: request, authRequired: false)
        
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
        
        _ = try? await performDataTask(for: request)
    }
    
    func fetchProfile(userId: String) async throws -> Profile {
        guard let url = URL(string: "\(SupabaseConfig.url)/rest/v1/profiles?id=eq.\(userId)&select=*") else {
            throw SupabaseError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.allHTTPHeaderFields = defaultHeaders(authRequired: true)
        
        let data = try await performDataTask(for: request)
        
        let profiles = try JSONDecoder().decode([Profile].self, from: data)
        guard let profile = profiles.first else {
            throw SupabaseError.decodingError
        }
        return profile
    }
    
    // MARK: - Database sync: Carts (Shopping Spaces) — FAST BULK FETCH
    
    func fetchSpaces() async throws -> [Cart] {
        guard session != nil else { return [] }
        guard let url = URL(string: "\(SupabaseConfig.url)/rest/v1/shopping_spaces?select=*") else {
            throw SupabaseError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.allHTTPHeaderFields = defaultHeaders(authRequired: true)
        
        let data = try await performDataTask(for: request)
        let dbSpaces = try JSONDecoder().decode([DBShoppingSpace].self, from: data)
        
        guard !dbSpaces.isEmpty else { return [] }
        
        // Single bulk query for all cart items across all spaces (replaces slow N+1 loop)
        let allItemsBySpace = (try? await fetchAllCartItems()) ?? [:]
        
        var carts: [Cart] = []
        for dbSpace in dbSpaces {
            if let uuid = UUID(uuidString: dbSpace.id) {
                let items = allItemsBySpace[dbSpace.id.lowercased()] ?? []
                let cart = Cart(id: uuid, name: dbSpace.name, items: items, createdBy: dbSpace.created_by)
                carts.append(cart)
            }
        }
        return carts
    }
    
    /// Bulk fetch all cart items across all user spaces in a single HTTP request
    private func fetchAllCartItems() async throws -> [String: [Item]] {
        guard let url = URL(string: "\(SupabaseConfig.url)/rest/v1/cart_items?select=*,profiles:added_by(display_name,email)") else {
            throw SupabaseError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.allHTTPHeaderFields = defaultHeaders(authRequired: true)
        
        let data = try await performDataTask(for: request)
        let dbItems = try JSONDecoder().decode([DBCartItem].self, from: data)
        
        var spaceItemsMap: [String: [Item]] = [:]
        
        for dbItem in dbItems {
            let spaceKey = dbItem.space_id.lowercased()
            let baseId = dbItem.item_id.components(separatedBy: "-pack").first ?? dbItem.item_id
            
            if var baseItem = AppViewModel.staticProducts.first(where: { $0.id == baseId }) {
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
                
                baseItem.addedByUserId = dbItem.added_by
                baseItem.addedByUserName = dbItem.profiles?.display_name ?? dbItem.profiles?.email ?? "Unknown User"
                
                for _ in 0..<dbItem.quantity {
                    spaceItemsMap[spaceKey, default: []].append(baseItem)
                }
            }
        }
        
        return spaceItemsMap
    }
    
    func createSpace(id: UUID, name: String) async throws {
        guard let session = session else { return }
        guard let url = URL(string: "\(SupabaseConfig.url)/rest/v1/shopping_spaces") else {
            throw SupabaseError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        var headers = defaultHeaders(authRequired: true)
        headers["Prefer"] = "resolution=merge-duplicates"
        request.allHTTPHeaderFields = headers
        
        let body: [String: Any] = [
            "id": id.uuidString.lowercased(),
            "name": name,
            "created_by": session.userId
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        _ = try? await performDataTask(for: request)
    }
    
    func deleteSpace(id: UUID) async throws {
        guard let url = URL(string: "\(SupabaseConfig.url)/rest/v1/shopping_spaces?id=eq.\(id.uuidString.lowercased())") else {
            throw SupabaseError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        request.allHTTPHeaderFields = defaultHeaders(authRequired: true)
        
        _ = try? await performDataTask(for: request)
    }
    
    func shareSpace(spaceId: UUID, withEmail email: String) async throws {
        let cleanEmail = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !cleanEmail.isEmpty else { return }
        
        guard let fetchUrl = URL(string: "\(SupabaseConfig.url)/rest/v1/profiles?email=eq.\(cleanEmail)&select=id,email") else {
            throw SupabaseError.invalidURL
        }
        
        var fetchRequest = URLRequest(url: fetchUrl)
        fetchRequest.httpMethod = "GET"
        fetchRequest.allHTTPHeaderFields = defaultHeaders(authRequired: true)
        
        var targetUserId: String? = nil
        if let data = try? await performDataTask(for: fetchRequest) {
            struct ProfileId: Decodable {
                let id: String
            }
            if let profiles = try? JSONDecoder().decode([ProfileId].self, from: data), let firstId = profiles.first?.id {
                targetUserId = firstId
            }
        }
        
        let userIdToInsert = targetUserId ?? cleanEmail
        
        guard let insertUrl = URL(string: "\(SupabaseConfig.url)/rest/v1/space_members") else {
            throw SupabaseError.invalidURL
        }
        
        var insertRequest = URLRequest(url: insertUrl)
        insertRequest.httpMethod = "POST"
        var headers = defaultHeaders(authRequired: true)
        headers["Prefer"] = "resolution=merge-duplicates"
        insertRequest.allHTTPHeaderFields = headers
        
        let body: [String: Any] = [
            "space_id": spaceId.uuidString.lowercased(),
            "user_id": userIdToInsert,
            "role": "member"
        ]
        insertRequest.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        do {
            _ = try await performDataTask(for: insertRequest)
        } catch {
            print("Notice: space_members insert handled: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Database sync: Cart Items
    
    func syncCartItems(spaceId: UUID, items: [Item]) async throws {
        guard let session = session else { return }
        
        guard let deleteUrl = URL(string: "\(SupabaseConfig.url)/rest/v1/cart_items?space_id=eq.\(spaceId.uuidString.lowercased())") else {
            throw SupabaseError.invalidURL
        }
        var deleteRequest = URLRequest(url: deleteUrl)
        deleteRequest.httpMethod = "DELETE"
        deleteRequest.allHTTPHeaderFields = defaultHeaders(authRequired: true)
        
        _ = try? await performDataTask(for: deleteRequest)
        
        guard !items.isEmpty else { return }
        
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
        
        guard let insertUrl = URL(string: "\(SupabaseConfig.url)/rest/v1/cart_items") else {
            throw SupabaseError.invalidURL
        }
        var insertRequest = URLRequest(url: insertUrl)
        insertRequest.httpMethod = "POST"
        insertRequest.allHTTPHeaderFields = defaultHeaders(authRequired: true)
        insertRequest.httpBody = try JSONSerialization.data(withJSONObject: dbItems)
        
        _ = try? await performDataTask(for: insertRequest)
    }
    
    // MARK: - Utilities
    
    private func handleStatus(_ response: URLResponse, data: Data) throws {
        guard let http = response as? HTTPURLResponse else {
            throw SupabaseError.unknown
        }
        if http.statusCode >= 300 {
            var message = "Request failed"
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                message = json["message"] as? String ?? json["error_description"] as? String ?? json["msg"] as? String ?? message
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
