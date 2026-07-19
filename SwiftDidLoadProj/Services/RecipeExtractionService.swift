import Foundation

// MARK: - RecipeExtractionService
// Multi-strategy extraction pipeline:
// 1. Fetch HTML from the shared URL and parse <meta> og:title / og:description
// 2. Try Instagram oEmbed API as backup
// 3. If on iOS 26+ with Apple Intelligence available, use FoundationModels for smart extraction
// 4. Fall back to keyword matching against a comprehensive recipe database
// 5. Match extracted ingredients to our product catalog

actor RecipeExtractionService {
    static let shared = RecipeExtractionService()

    // MARK: - Main Pipeline

    func extractRecipe(from urlString: String) async throws -> Recipe {
        // Strategy 1: Fetch HTML meta tags from the URL
        var pageText = await fetchHTMLMetaTags(from: urlString)

        // Strategy 2: Try oEmbed if HTML fetch returned nothing useful
        if pageText.isEmpty {
            pageText = await fetchOEmbed(from: urlString)
        }

        // Strategy 3: Use the raw URL itself as context (Instagram URLs often contain clues)
        if pageText.isEmpty {
            pageText = urlString
        }

        // Strategy 4: Try Foundation Models (Apple Intelligence) for smart extraction
        #if canImport(FoundationModels)
        if #available(iOS 26.0, *) {
            if let aiRecipe = await FoundationModelsExtractor.extract(from: pageText) {
                return aiRecipe
            }
        }
        #endif

        // Strategy 5: Fall back to keyword matching
        return extractFromText(pageText)
    }

    // MARK: - Strategy 1: Fetch HTML and parse <meta> tags

    private func fetchHTMLMetaTags(from urlString: String) async -> String {
        guard !urlString.isEmpty, urlString != "no-url",
              let url = URL(string: urlString) else { return "" }

        do {
            var request = URLRequest(url: url)
            request.timeoutInterval = 8
            // Pretend to be a browser so Instagram returns full HTML
            request.setValue("Mozilla/5.0 (iPhone; CPU iPhone OS 18_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.0 Mobile/15E148 Safari/604.1", forHTTPHeaderField: "User-Agent")

            let (data, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200,
                  let html = String(data: data, encoding: .utf8) else { return "" }

            // Parse og:title
            let ogTitle = extractMetaContent(from: html, property: "og:title")
            // Parse og:description
            let ogDescription = extractMetaContent(from: html, property: "og:description")
            // Parse regular title
            let pageTitle = extractHTMLTitle(from: html)

            let combined = [ogTitle, ogDescription, pageTitle]
                .filter { !$0.isEmpty }
                .joined(separator: " | ")

            return combined
        } catch {
            return ""
        }
    }

    // Extract content from <meta property="..." content="...">
    private func extractMetaContent(from html: String, property: String) -> String {
        // Pattern: <meta property="og:title" content="...">
        // Also handles: <meta name="description" content="...">
        let patterns = [
            "property=\"\(property)\"\\s+content=\"([^\"]+)\"",
            "content=\"([^\"]+)\"\\s+property=\"\(property)\"",
            "name=\"\(property)\"\\s+content=\"([^\"]+)\"",
            "content=\"([^\"]+)\"\\s+name=\"\(property)\""
        ]

        for pattern in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
               let match = regex.firstMatch(in: html, range: NSRange(html.startIndex..., in: html)) {
                let nsRange = match.range(at: 1)
                if nsRange.location != NSNotFound, let range = Range(nsRange, in: html) {
                    return String(html[range])
                }
            }
        }
        return ""
    }

    // Extract <title>...</title>
    private func extractHTMLTitle(from html: String) -> String {
        if let regex = try? NSRegularExpression(pattern: "<title[^>]*>([^<]+)</title>", options: .caseInsensitive),
           let match = regex.firstMatch(in: html, range: NSRange(html.startIndex..., in: html)) {
            let nsRange = match.range(at: 1)
            if nsRange.location != NSNotFound, let range = Range(nsRange, in: html) {
                return String(html[range]).trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }
        return ""
    }

    // MARK: - Strategy 2: Instagram oEmbed API

    private func fetchOEmbed(from urlString: String) async -> String {
        guard let encoded = urlString.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let url = URL(string: "https://api.instagram.com/oembed?url=\(encoded)&format=json") else { return "" }

        do {
            var request = URLRequest(url: url)
            request.timeoutInterval = 5
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return "" }

            let title = json["title"] as? String ?? ""
            let author = json["author_name"] as? String ?? ""
            return "\(author) \(title)".trimmingCharacters(in: .whitespaces)
        } catch {
            return ""
        }
    }

    // MARK: - Extract Recipe from Text (keyword matching fallback)

    private func extractFromText(_ text: String) -> Recipe {
        let lower = text.lowercased()

        // === RECIPE DISH MAPPINGS ===
        // Each entry: keywords to match → recipe name → list of (ingredient name, search terms)
        let recipes: [(keys: [String], name: String, items: [(String, [String])])] = [
            // Indian curries
            (["paneer tikka", "tikka masala", "paneer masala", "shahi paneer"],
             "Paneer Tikka Masala",
             [("Paneer", ["paneer"]), ("Curd", ["curd", "dahi"]), ("Butter", ["butter"]),
              ("Oil", ["oil"]), ("Salt", ["salt"]), ("Tomato Sauce", ["ketchup", "sauce"])]),

            (["butter chicken", "murgh makhani"],
             "Butter Chicken",
             [("Butter", ["butter"]), ("Curd", ["curd", "dahi"]), ("Oil", ["oil"]),
              ("Milk", ["milk"]), ("Salt", ["salt"]), ("Tomato Sauce", ["ketchup", "sauce"])]),

            (["dal makhani", "dal makhni", "black dal"],
             "Dal Makhani",
             [("Toor Dal", ["dal", "toor dal"]), ("Butter", ["butter"]),
              ("Milk", ["milk"]), ("Salt", ["salt"])]),

            (["chole bhature", "chole", "chana masala", "chickpea"],
             "Chole Bhature",
             [("Oil", ["oil"]), ("Salt", ["salt"]), ("Atta", ["atta", "wheat flour"]),
              ("Curd", ["curd", "dahi"])]),

            (["rajma", "kidney bean"],
             "Rajma Chawal",
             [("Basmati Rice", ["rice", "basmati"]), ("Oil", ["oil"]),
              ("Salt", ["salt"]), ("Tomato Sauce", ["ketchup", "sauce"])]),

            (["aloo gobi", "aloo gobhi"],
             "Aloo Gobi",
             [("Oil", ["oil"]), ("Salt", ["salt"]), ("Butter", ["butter"])]),

            (["palak paneer", "saag paneer"],
             "Palak Paneer",
             [("Paneer", ["paneer"]), ("Butter", ["butter"]), ("Milk", ["milk"]),
              ("Salt", ["salt"]), ("Oil", ["oil"])]),

            // Rice dishes
            (["biryani", "dum biryani", "chicken biryani", "veg biryani", "hyderabadi"],
             "Biryani",
             [("Basmati Rice", ["rice", "basmati"]), ("Curd", ["curd", "dahi"]),
              ("Oil", ["oil"]), ("Salt", ["salt"]), ("Butter", ["butter"])]),

            (["pulao", "pilaf", "fried rice"],
             "Pulao",
             [("Basmati Rice", ["rice", "basmati"]), ("Oil", ["oil"]),
              ("Butter", ["butter"]), ("Salt", ["salt"])]),

            // Breakfast
            (["poha", "aloo poha", "beaten rice"],
             "Poha",
             [("Oil", ["oil"]), ("Salt", ["salt"]), ("Curd", ["curd"])]),

            (["paratha", "aloo paratha", "stuffed paratha", "gobi paratha"],
             "Paratha",
             [("Atta", ["atta", "wheat flour"]), ("Butter", ["butter"]),
              ("Oil", ["oil"]), ("Salt", ["salt"]), ("Curd", ["curd", "dahi"])]),

            (["dosa", "masala dosa", "idli", "uttapam"],
             "Dosa / Idli",
             [("Oil", ["oil"]), ("Butter", ["butter"]), ("Salt", ["salt"]),
              ("Curd", ["curd", "dahi"])]),

            (["omelette", "omelet", "egg", "scrambled egg", "egg curry"],
             "Egg Recipe",
             [("Eggs", ["eggs"]), ("Butter", ["butter"]), ("Oil", ["oil"]),
              ("Salt", ["salt"]), ("Bread", ["bread"])]),

            (["sandwich", "bread toast", "toast", "grilled sandwich"],
             "Sandwich",
             [("Bread", ["bread"]), ("Butter", ["butter"]), ("Eggs", ["eggs"]),
              ("Tomato Sauce", ["ketchup"]), ("Salt", ["salt"])]),

            // Western / Fusion
            (["pasta", "spaghetti", "penne", "macaroni", "mac and cheese", "alfredo"],
             "Pasta",
             [("Butter", ["butter"]), ("Milk", ["milk"]),
              ("Tomato Sauce", ["ketchup", "sauce"]), ("Salt", ["salt"])]),

            (["pizza", "pizza dough"],
             "Pizza",
             [("Atta", ["atta", "wheat flour"]), ("Tomato Sauce", ["ketchup", "sauce"]),
              ("Oil", ["oil"]), ("Salt", ["salt"]), ("Butter", ["butter"])]),

            (["pancake", "waffle", "french toast"],
             "Pancakes",
             [("Eggs", ["eggs"]), ("Milk", ["milk"]), ("Butter", ["butter"]),
              ("Atta", ["atta", "wheat flour"]), ("Salt", ["salt"])]),

            (["cake", "baking", "brownie", "muffin", "cupcake"],
             "Baking",
             [("Eggs", ["eggs"]), ("Milk", ["milk"]), ("Butter", ["butter"]),
              ("Atta", ["atta", "wheat flour"]), ("Chocolate", ["chocolate", "cadbury"]),
              ("Salt", ["salt"])]),

            (["smoothie", "milkshake", "shake", "lassi"],
             "Smoothie / Shake",
             [("Milk", ["milk"]), ("Curd", ["curd", "dahi"])]),

            // Snacks
            (["samosa", "spring roll", "pakora", "pakoda", "bhajiya"],
             "Snacks",
             [("Oil", ["oil"]), ("Atta", ["atta", "wheat flour"]),
              ("Salt", ["salt"]), ("Tomato Sauce", ["ketchup", "sauce"])]),

            (["maggi", "noodle", "ramen", "instant noodle"],
             "Maggi Noodles",
             [("Maggi", ["maggi", "noodles"]), ("Butter", ["butter"]),
              ("Eggs", ["eggs"]), ("Salt", ["salt"])]),

            // Drinks
            (["chai", "tea", "masala chai"],
             "Chai",
             [("Milk", ["milk"]), ("Salt", ["salt"])]),

            (["coffee", "cold coffee", "iced coffee"],
             "Coffee",
             [("Milk", ["milk"]), ("Chocolate", ["chocolate", "cadbury"])]),
        ]

        // Match recipes
        for recipe in recipes {
            if recipe.keys.contains(where: { lower.contains($0) }) {
                return Recipe(
                    name: recipe.name,
                    ingredients: recipe.items.map { RecipeIngredient(genericName: $0.0, searchTerms: $0.1) }
                )
            }
        }

        // === SINGLE PRODUCT MAPPINGS ===
        let products: [(keys: [String], name: String, terms: [String])] = [
            (["coca cola", "coke", "coca-cola"], "Coca-Cola", ["coke", "cola"]),
            (["sprite"], "Sprite", ["sprite"]),
            (["thums up", "thumbs up"], "Thums Up", ["thums up", "cola"]),
            (["pepsi"], "Pepsi", ["pepsi", "cola"]),
            (["lay's", "lays", "chips"], "Lay's Chips", ["chips", "lays"]),
            (["kurkure"], "Kurkure", ["kurkure", "namkeen"]),
            (["haldiram", "bhujia"], "Haldiram's", ["bhujia", "haldiram", "namkeen"]),
            (["cadbury", "dairy milk", "chocolate", "silk"], "Cadbury", ["chocolate", "cadbury"]),
            (["colgate", "toothpaste"], "Colgate", ["toothpaste", "colgate"]),
            (["dove", "soap"], "Dove", ["soap", "dove"]),
            (["surf", "detergent", "washing"], "Surf Excel", ["detergent", "surf excel"]),
        ]

        for product in products {
            if product.keys.contains(where: { lower.contains($0) }) {
                return Recipe(
                    name: product.name,
                    ingredients: [RecipeIngredient(genericName: product.name, searchTerms: product.terms)]
                )
            }
        }

        // === GENERIC FOOD KEYWORDS ===
        // If we detect any food-related words, build a general cooking recipe
        let foodKeywords = ["recipe", "cook", "food", "dish", "meal", "kitchen", "ingredient",
                            "delicious", "tasty", "yummy", "homemade", "healthy", "dinner",
                            "lunch", "breakfast", "snack", "khana", "sabzi", "roti"]

        if foodKeywords.contains(where: { lower.contains($0) }) {
            return Recipe(
                name: "Recipe from Reel",
                ingredients: [
                    RecipeIngredient(genericName: "Oil", searchTerms: ["oil", "refined oil"]),
                    RecipeIngredient(genericName: "Salt", searchTerms: ["salt"]),
                    RecipeIngredient(genericName: "Butter", searchTerms: ["butter"]),
                    RecipeIngredient(genericName: "Atta", searchTerms: ["atta", "wheat flour"]),
                    RecipeIngredient(genericName: "Milk", searchTerms: ["milk"]),
                    RecipeIngredient(genericName: "Eggs", searchTerms: ["eggs"]),
                ]
            )
        }

        // Absolute fallback — show popular grocery staples
        return Recipe(
            name: "Popular Groceries",
            ingredients: [
                RecipeIngredient(genericName: "Milk", searchTerms: ["milk"]),
                RecipeIngredient(genericName: "Bread", searchTerms: ["bread"]),
                RecipeIngredient(genericName: "Eggs", searchTerms: ["eggs"]),
                RecipeIngredient(genericName: "Butter", searchTerms: ["butter"]),
                RecipeIngredient(genericName: "Salt", searchTerms: ["salt"]),
                RecipeIngredient(genericName: "Oil", searchTerms: ["oil", "refined oil"]),
            ]
        )
    }

    // MARK: - Search Term Helper

    static func generateSearchTerms(for ingredient: String) -> [String] {
        let lower = ingredient.lowercased()
        var terms = [lower]
        let aliasMap: [String: [String]] = [
            "paneer": ["paneer", "cottage cheese"], "curd": ["curd", "dahi"],
            "oil": ["oil", "refined oil"], "ghee": ["ghee"], "butter": ["butter"],
            "milk": ["milk"], "salt": ["salt"], "rice": ["rice", "basmati"],
            "dal": ["dal", "toor dal", "arhar"], "atta": ["atta", "wheat flour"],
            "bread": ["bread"], "eggs": ["eggs"], "ketchup": ["ketchup", "tomato sauce"],
            "chocolate": ["chocolate", "cadbury"], "chips": ["chips", "lays"],
            "noodles": ["noodles", "maggi"], "maggi": ["maggi", "noodles"],
        ]
        for (key, aliases) in aliasMap {
            if lower.contains(key) { terms.append(contentsOf: aliases) }
        }
        return Array(Set(terms))
    }
}
