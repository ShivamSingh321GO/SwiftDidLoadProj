// FoundationModelsService.swift
// Conditionally compiled only when FoundationModels framework is available (iOS 26+ / Xcode 26+)
// This file is intentionally separate to avoid import errors on older SDKs.

#if canImport(FoundationModels)
import FoundationModels
import Foundation

@available(iOS 26.0, *)
extension FoundationModelsExtractor {

    // Override the stub in RecipeExtractionService.swift with the real implementation
    static func extract(from text: String) async -> Recipe? {
        let model = SystemLanguageModel.default

        guard model.isAvailable else {
            return nil
        }

        let session = LanguageModelSession()

        let prompt = """
        You are a grocery shopping assistant for an Indian grocery delivery app.
        Given a food recipe title or description, extract the main grocery ingredients needed to cook it.

        Return ONLY a valid JSON object with NO extra explanation text, in exactly this format:
        {
          "recipeName": "Name of the dish",
          "ingredients": ["ingredient1", "ingredient2", "ingredient3"]
        }

        Rules:
        - List only grocery food items (not equipment like pans or bowls)
        - Use short generic names (e.g., "oil" not "sunflower refined oil")
        - Maximum 8 ingredients
        - Prioritize common Indian grocery items

        Recipe description: \(text)
        """

        do {
            let response = try await session.respond(to: prompt)
            return parseResponse(response.content)
        } catch {
            return nil
        }
    }

    private static func parseResponse(_ content: String) -> Recipe? {
        // Extract the JSON block from the response
        guard let jsonStart = content.firstIndex(of: "{"),
              let jsonEnd = content.lastIndex(of: "}") else {
            return nil
        }

        let jsonString = String(content[jsonStart...jsonEnd])
        guard let data = jsonString.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let ingredientsArray = json["ingredients"] as? [String],
              !ingredientsArray.isEmpty else {
            return nil
        }

        let recipeName = json["recipeName"] as? String ?? "Recipe from Reel"

        let ingredients = ingredientsArray.map { name -> RecipeIngredient in
            let searchTerms = RecipeExtractionService.generateSearchTerms(for: name)
            return RecipeIngredient(genericName: name.capitalized, searchTerms: searchTerms)
        }

        return Recipe(name: recipeName, ingredients: ingredients)
    }
}
#endif
