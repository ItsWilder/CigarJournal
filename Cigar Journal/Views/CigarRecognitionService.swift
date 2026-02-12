import Foundation
import UIKit
import Vision

#if canImport(FoundationModels)
import FoundationModels
#endif

enum CigarRecognitionError: LocalizedError {
    case invalidImage
    case noPhoto

    var errorDescription: String? {
        switch self {
        case .invalidImage:
            return "The selected photo could not be processed."
        case .noPhoto:
            return "Add a photo first, then try identifying the cigar."
        }
    }
}

enum CigarSuggestionSource: String {
    case vision
    case appleIntelligence
}

struct CigarFieldSuggestion {
    let value: String
    let confidence: Double
    let source: CigarSuggestionSource
}

struct CigarRecognitionResult {
    var extractedText: [String]
    var name: CigarFieldSuggestion?
    var type: CigarFieldSuggestion?
    var length: CigarFieldSuggestion?
    var gauge: CigarFieldSuggestion?
    var strength: CigarFieldSuggestion?

    var suggestionCount: Int {
        [name, type, length, gauge, strength].compactMap { $0 }.count
    }

    var sourceLabel: String {
        let includesAI = [name, type, length, gauge, strength]
            .compactMap { $0?.source }
            .contains(.appleIntelligence)
        return includesAI ? "Apple Intelligence + Vision" : "Vision"
    }
}

actor CigarRecognitionService {
    private let parser = CigarTextParser()

    func recognize(
        photoData: Data?,
        typeOptions: [String],
        strengthOptions: [String]
    ) async throws -> CigarRecognitionResult {
        guard let photoData else {
            throw CigarRecognitionError.noPhoto
        }
        guard let image = UIImage(data: photoData),
              let cgImage = image.cgImage else {
            throw CigarRecognitionError.invalidImage
        }

        let lines = try await extractTextLines(from: cgImage)
        var result = parser.parse(lines: lines, typeOptions: typeOptions, strengthOptions: strengthOptions)

#if canImport(FoundationModels)
        if #available(iOS 26.0, *),
           let aiResult = await AppleIntelligenceCigarExtractor().extract(
            textLines: lines,
            typeOptions: typeOptions,
            strengthOptions: strengthOptions
           ) {
            result = merge(base: result, ai: aiResult)
        }
#endif

        return result
    }

    private func merge(base: CigarRecognitionResult, ai: CigarRecognitionResult) -> CigarRecognitionResult {
        var merged = base

        if let aiName = ai.name {
            merged.name = aiName
        }
        if let aiType = ai.type {
            merged.type = aiType
        }
        if let aiLength = ai.length {
            merged.length = aiLength
        }
        if let aiGauge = ai.gauge {
            merged.gauge = aiGauge
        }
        if let aiStrength = ai.strength {
            merged.strength = aiStrength
        }

        return merged
    }

    private func extractTextLines(from image: CGImage) async throws -> [String] {
        try await withCheckedThrowingContinuation { continuation in
            let request = VNRecognizeTextRequest { request, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }

                let observations = request.results as? [VNRecognizedTextObservation] ?? []
                let lines = observations
                    .compactMap { $0.topCandidates(1).first?.string }
                    .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                    .filter { !$0.isEmpty }

                continuation.resume(returning: lines)
            }

            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = true
            request.recognitionLanguages = ["en-US", "es-US"]

            do {
                let handler = VNImageRequestHandler(cgImage: image, options: [:])
                try handler.perform([request])
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }
}

private struct CigarTextParser {
    private let sizePattern = try? NSRegularExpression(
        pattern: #"\b(\d(?:\.\d{1,2})?)\s*(?:x|×)\s*(\d{2})\b"#,
        options: [.caseInsensitive]
    )

    func parse(lines: [String], typeOptions: [String], strengthOptions: [String]) -> CigarRecognitionResult {
        let joined = lines.joined(separator: " ")

        let parsedSize = parseLengthAndGauge(from: joined)
        let matchedStrength = matchStrength(in: joined, options: strengthOptions)
        let matchedType = matchType(in: joined, options: typeOptions)
        let guessedName = guessName(from: lines, excluding: typeOptions + strengthOptions)

        return CigarRecognitionResult(
            extractedText: lines,
            name: guessedName.map {
                CigarFieldSuggestion(value: $0, confidence: 0.68, source: .vision)
            },
            type: matchedType.map {
                CigarFieldSuggestion(value: $0, confidence: 0.65, source: .vision)
            },
            length: parsedSize.length.map {
                CigarFieldSuggestion(value: $0, confidence: 0.84, source: .vision)
            },
            gauge: parsedSize.gauge.map {
                CigarFieldSuggestion(value: $0, confidence: 0.84, source: .vision)
            },
            strength: matchedStrength.map {
                CigarFieldSuggestion(value: $0, confidence: 0.66, source: .vision)
            }
        )
    }

    private func parseLengthAndGauge(from text: String) -> (length: String?, gauge: String?) {
        guard let sizePattern else {
            return (nil, nil)
        }

        let range = NSRange(location: 0, length: text.utf16.count)
        guard let match = sizePattern.firstMatch(in: text, options: [], range: range),
              let lengthRange = Range(match.range(at: 1), in: text),
              let gaugeRange = Range(match.range(at: 2), in: text) else {
            return (nil, nil)
        }

        let rawLength = String(text[lengthRange])
        let rawGauge = String(text[gaugeRange])

        guard let lengthValue = Double(rawLength) else {
            return (nil, nil)
        }

        return (String(format: "%.2f", lengthValue), rawGauge)
    }

    private func matchStrength(in text: String, options: [String]) -> String? {
        let lowered = text.lowercased()

        if lowered.contains("full") || lowered.contains("strong") {
            return options.first { $0.caseInsensitiveCompare("Strong") == .orderedSame } ?? "Strong"
        }
        if lowered.contains("medium") {
            return options.first { $0.caseInsensitiveCompare("Medium") == .orderedSame } ?? "Medium"
        }
        if lowered.contains("mild") {
            return options.first { $0.caseInsensitiveCompare("Mild") == .orderedSame } ?? "Mild"
        }

        return nil
    }

    private func matchType(in text: String, options: [String]) -> String? {
        let lowered = text.lowercased()

        return options.first { option in
            lowered.contains(option.lowercased())
        }
    }

    private func guessName(from lines: [String], excluding exclusions: [String]) -> String? {
        let badTokens = Set([
            "habano", "nicaragua", "dominican", "handmade", "premium", "imported", "cigar", "cigars"
        ] + exclusions.map { $0.lowercased() })

        let candidate = lines
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { $0.count >= 3 && $0.count <= 36 }
            .filter { line in
                let lower = line.lowercased()
                return !badTokens.contains(lower)
            }
            .first

        return candidate
    }
}

#if canImport(FoundationModels)
@available(iOS 26.0, *)
private struct AppleIntelligenceCigarExtractor {
    func extract(textLines: [String], typeOptions: [String], strengthOptions: [String]) async -> CigarRecognitionResult? {
        let joinedText = textLines.joined(separator: "\n")

        let prompt = """
        You normalize OCR output from a cigar photo into JSON.
        Return exactly one compact JSON object with these keys only:
        name, type, length, gauge, strength, confidence

        Rules:
        - type must be one of: \(typeOptions.joined(separator: ", "))
        - strength must be one of: \(strengthOptions.joined(separator: ", "))
        - length format must be ##.## inches string, example 6.00
        - gauge must be a numeric string
        - confidence is a number between 0.0 and 1.0
        - Use null for unknown values.

        OCR text:
        \(joinedText)
        """

        do {
            let session = LanguageModelSession()
            let response = try await session.respond(to: prompt)
            return parse(response.content)
        } catch {
            return nil
        }
    }

    private func parse(_ content: String) -> CigarRecognitionResult? {
        guard let jsonData = extractJSONObject(from: content)?.data(using: .utf8) else {
            return nil
        }

        guard let object = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any] else {
            return nil
        }

        let confidence = max(0.0, min(1.0, object["confidence"] as? Double ?? 0.72))

        func suggestion(for key: String) -> CigarFieldSuggestion? {
            guard let value = object[key] as? String else {
                return nil
            }
            let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else {
                return nil
            }
            return CigarFieldSuggestion(value: trimmed, confidence: confidence, source: .appleIntelligence)
        }

        return CigarRecognitionResult(
            extractedText: [],
            name: suggestion(for: "name"),
            type: suggestion(for: "type"),
            length: suggestion(for: "length"),
            gauge: suggestion(for: "gauge"),
            strength: suggestion(for: "strength")
        )
    }

    private func extractJSONObject(from content: String) -> String? {
        guard let start = content.firstIndex(of: "{"),
              let end = content.lastIndex(of: "}") else {
            return nil
        }

        return String(content[start...end])
    }
}
#endif
