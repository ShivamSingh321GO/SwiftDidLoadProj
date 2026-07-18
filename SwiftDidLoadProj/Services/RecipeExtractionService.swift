import Foundation

// MARK: - RecipeExtractionService
// Uses Instagram's public oEmbed API to get reel metadata,
// then uses Apple Foundation Models (on-device AI) to extract ingredients.
// Falls back to heuristic keyword matching on older devices.

actor RecipeExtractionService {

    static let shared = RecipeExtractionService()

    // MARK: - Main Entry Point

    func extractRecipe(from urlString: String) async throws -> Recipe {
        let pageText = await fetchPageText(from: urlString)
        let recipe = await extractIngredients(from: pageText)
        return recipe
    }

    // MARK: - Step 1: Fetch Page Text via oEmbed

    private func fetchPageText(from urlString: String) async -> String {
        guard let encodedURL = urlString.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let oembedURL = URL(string: "https://api.instagram.com/oembed?url=\(encodedURL)&format=json") else {
            return "Recipe from: \(urlString)"
        }
        do {
            let (data, response) = try await URLSession.shared.data(from: oembedURL)
            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                return "Recipe from: \(urlString)"
            }
            let title = json["title"] as? String ?? ""
            let authorName = json["author_name"] as? String ?? ""
            return "Instagram Reel by @\(authorName): \(title)"
        } catch {
            return "Recipe from: \(urlString)"
        }
    }

    // MARK: - Step 2: Extract Ingredients

    private func extractIngredients(from text: String) async -> Recipe {
        #if canImport(FoundationModels)
        if #available(iOS 26.0, *) {
            if let recipe = await FoundationModelsExtractor.extract(from: text) {
                return recipe
            }
        }
        #endif
        return heuristicExtraction(from: text)
    }

    // MARK: - Heuristic Fallback

    private func heuristicExtraction(from text: String) -> Recipe {
        let lowercased = text.lowercased()

        let dishMappings: [(keywords: [String], recipe: String, ingredients: [(String, [String])])] = [
            (
                ["paneer tikka", "tikka masala", "paneer tikka masala"],
                "Paneer Tikka Masala",
                [("Paneer", ["paneer"]), ("Curd / Dahi", ["curd", "dahi"]), ("Butter", ["butter"]), ("Oil", ["oil"]), ("Salt", ["salt"])]
            ),
            (
                ["dal makhani", "dal makhni"],
                "Dal Makhani",
                [("Toor Dal", ["dal", "toor dal"]), ("Butter", ["butter"]), ("Milk", ["milk"]), ("Salt", ["salt"])]
            ),
            (
                ["biryani", "dum biryani"],
                "Biryani",
                [("Basmati Rice", ["rice", "basmati"]), ("Curd", ["curd", "dahi"]), ("Oil", ["oil"]), ("Salt", ["salt"])]
            ),
            (
                ["pasta", "spaghetti", "penne"],
                "Pasta",
                [("Butter", ["butter"]), ("Milk", ["milk"]), ("Tomato Sauce", ["ketchup", "sauce"]), ("Salt", ["salt"])]
            ),
            (
                ["sandwich", "bread toast", "toast"],
                "Sandwich",
                [("Bread", ["bread"]), ("Butter", ["butter"]), ("Eggs", ["eggs"]), ("Tomato Sauce", ["ketchup"])]
            ),
            (
                ["poha", "aloo poha"],
                "Poha",
                [("Oil", ["oil"]), ("Salt", ["salt"]), ("Curd", ["curd"])]
            )
        ]

        for mapping in dishMappings {
            if mapping.keywords.contains(where: { lowercased.contains($0) }) {
                return Recipe(
                    name: mapping.recipe,
                    ingredients: mapping.ingredients.map { RecipeIngredient(genericName: $0.0, searchTerms: $0.1) }
                )
            }
        }

        return AppViewModel.mockRecipe
    }

    // MARK: - Search Term Generation Helper (used by FoundationModelsService)

    static func generateSearchTerms(for ingredient: String) -> [String] {
        let lower = ingredient.lowercased()
        var terms = [lower]
        let aliasMap: [String: [String]] = [
            "paneer": ["paneer", "cottage cheese"],
            "curd": ["curd", "dahi"],
            "oil": ["oil", "refined oil"],
            "ghee": ["ghee"],
            "butter": ["butter"],
            "milk": ["milk"],
            "salt": ["salt"],
            "rice": ["rice", "basmati"],
            "dal": ["dal", "toor dal", "arhar"],
            "atta": ["atta", "wheat flour"],
            "bread": ["bread"],
            "eggs": ["eggs"],
            "ketchup": ["ketchup", "tomato sauce"],
            "chocolate": ["chocolate", "cadbury"],
            "chips": ["chips", "lays"],
            "noodles": ["noodles", "maggi"]
        ]
        for (key, aliases) in aliasMap {
            if lower.contains(key) { terms.append(contentsOf: aliases) }
        }
        return Array(Set(terms))
    }
}
