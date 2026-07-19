import Vision
import UIKit
import Foundation

// MARK: - HandwritingScannerService
// Uses Apple Vision VNRecognizeTextRequest to do on-device OCR of handwritten grocery lists.
// Works on iOS 13+, no internet or Apple Intelligence required.

actor HandwritingScannerService {
    static let shared = HandwritingScannerService()

    /// Scans a UIImage for handwritten text and returns recognized lines
    func recognizeText(from image: UIImage) async throws -> [String] {
        guard let cgImage = image.cgImage else {
            throw ScanError.invalidImage
        }

        return try await withCheckedThrowingContinuation { continuation in
            let request = VNRecognizeTextRequest { request, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }
                guard let results = request.results as? [VNRecognizedTextObservation] else {
                    continuation.resume(returning: [])
                    return
                }
                let lines = results.compactMap { obs -> String? in
                    obs.topCandidates(1).first?.string
                }
                continuation.resume(returning: lines)
            }

            // Accurate mode is best for handwriting
            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = true
            request.recognitionLanguages = ["en-US"]

            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            do {
                try handler.perform([request])
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }

    /// Matches recognized text lines to grocery items in the catalog
    func matchItems(from lines: [String], catalog: [Item]) -> [ScannedGroceryItem] {
        var results: [ScannedGroceryItem] = []
        for line in lines {
            let cleaned = line.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !cleaned.isEmpty else { continue }
            let matched = findBestMatch(for: cleaned, in: catalog)
            results.append(ScannedGroceryItem(rawText: cleaned, matchedProduct: matched, isSelected: matched != nil))
        }
        return results
    }

    private func findBestMatch(for text: String, in catalog: [Item]) -> Item? {
        // Remove quantities and units to get clean ingredient name
        var searchText = text.lowercased()
        let patterns = ["\\d+(\\.\\d+)?\\s*(kg|g|ml|l|litre|liter|pack|packet|pcs|piece|dozen|ltr)", "\\d+"]
        for pattern in patterns {
            searchText = (try? searchText.replacing(Regex(pattern), with: "")) ?? searchText
        }
        searchText = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !searchText.isEmpty else { return nil }

        var bestMatch: (item: Item, score: Int)? = nil

        for item in catalog {
            var score = 0

            if let aliases = item.aliases {
                for alias in aliases {
                    if searchText.contains(alias.lowercased()) || alias.lowercased().contains(searchText) {
                        score += 10
                    }
                }
            }
            if let sub = item.subCategory, searchText.contains(sub.lowercased()) { score += 7 }
            let nameWords = item.name.lowercased().components(separatedBy: " ")
            for word in nameWords where word.count > 3 {
                if searchText.contains(word) { score += 5 }
            }

            if score > 0, bestMatch == nil || score > bestMatch!.score {
                bestMatch = (item, score)
            }
        }

        return bestMatch?.item
    }

    enum ScanError: Error {
        case invalidImage
        case recognitionFailed
    }
}

// MARK: - ScannedGroceryItem Model
struct ScannedGroceryItem: Identifiable {
    let id = UUID()
    let rawText: String
    var matchedProduct: Item?
    var isSelected: Bool
}
