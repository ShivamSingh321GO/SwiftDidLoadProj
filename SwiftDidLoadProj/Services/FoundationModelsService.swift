// FoundationModelsService.swift
// Conditionally compiled only when FoundationModels framework is available (iOS 26+ / Xcode 26+)

#if canImport(FoundationModels)
import FoundationModels
import Foundation

// MARK: - Structured Output Schema

/// Type-safe structured output for on-device Apple Intelligence extraction.
/// Using @Generable ensures the model returns a well-typed struct — not free-form text.
@available(iOS 26.0, *)
@Generable
struct RecipeOutput {
    /// The dish name OR product name from the reel (e.g. "Paneer Tikka Masala", "Coca Cola")
    var name: String
    /// Items to add to a grocery cart — cooking ingredients for a recipe, or the product itself for packaged goods
    var itemsToBuy: [String]
}

// MARK: - Extractor

@available(iOS 26.0, *)
enum FoundationModelsExtractor {

    static func extract(from text: String) async -> Recipe? {
        let model = SystemLanguageModel.default

        switch model.availability {
        case .available:
            break // proceed
        case .unavailable(let reason):
            print("[FoundationModels] ⚠️ Model unavailable: \(reason)")
            return nil
        @unknown default:
            print("[FoundationModels] ⚠️ Unknown availability state.")
            return nil
        }

        let session = LanguageModelSession()

        let prompt = """
        You are a shopping assistant for Blinkit, an Indian instant grocery delivery app.
        Given a description of an Instagram reel about food or drinks, figure out what items the viewer should add to their grocery cart.

        Two cases:
        1. PACKAGED PRODUCT reel (e.g. Coca Cola ad, Lay's chips review, Maggi unboxing):
           → Return ONLY that product as the single item to buy.
           → Do NOT decompose it into raw ingredients (never say "water, sugar, caramel" for Coca Cola).

        2. RECIPE / COOKING reel (e.g. making Paneer Tikka Masala, Biryani, Pasta):
           → Return the grocery ingredients a viewer needs to buy to cook that dish.
           → Use short generic names: "paneer" not "fresh cottage cheese cubes".

        Rules for both cases:
        - Items must be purchasable from a grocery/convenience store.
        - Maximum 8 items.
        - Prefer common Indian grocery and FMCG brand names when relevant.

        Reel description: \(text)
        """

        do {
            let response = try await session.respond(
                to: prompt,
                generating: RecipeOutput.self
            )
            return buildRecipe(from: response.content)
        } catch {
            return nil
        }
    }

    // MARK: - Private

    private static func buildRecipe(from output: RecipeOutput) -> Recipe? {
        guard !output.itemsToBuy.isEmpty else { return nil }

        let ingredients = output.itemsToBuy.map { name -> RecipeIngredient in
            let terms = RecipeExtractionService.generateSearchTerms(for: name)
            return RecipeIngredient(genericName: name.capitalized, searchTerms: terms)
        }

        return Recipe(name: output.name, ingredients: ingredients)
    }
}
#endif
