// CigarLookupService
// Looks a cigar up on the web by (partial) name using Claude with web search.
//
// A brand name alone ("Acid", "H. Upmann") is ambiguous, so the service never picks
// one cigar: it returns a short list of real lines and sizes and the user chooses.
// An optional photo helps pick the line (band text, colors) and the size: sizes
// always come from the web, and the photo is only used to rank them.

import Foundation

struct CigarLookupCandidate: Identifiable, Hashable, Sendable {
    let id = UUID()
    /// Full name as commonly written, e.g. "Acid Kuba Kuba".
    let name: String
    /// Brand + line, used to group results, e.g. "Acid Classic".
    let line: String
    let vitola: String
    let lengthInches: Double?
    let ringGauge: Int?
    let shape: String?
    let strength: String?
    let wrapper: String?
    let binder: String?
    let filler: String?
    let origin: String?
    let sourceURL: URL?
    /// Whether this size looks consistent with the cigar in the photo.
    let matchesPhoto: Bool

    var sizeText: String? {
        switch (lengthInches, ringGauge) {
        case let (length?, gauge?): "\(CigarTemplate.formatLength(length))\" x \(gauge)"
        case let (length?, nil): "\(CigarTemplate.formatLength(length))\""
        case let (nil, gauge?): "\(gauge) ring"
        case (nil, nil): nil
        }
    }
}

struct CigarLookupResult: Sendable {
    let candidates: [CigarLookupCandidate]
    /// Claude's short explanation, e.g. "Acid is a brand; here are its best-known lines."
    let note: String
}

enum CigarLookupError: LocalizedError {
    case missingAPIKey
    case invalidAPIKey
    case busy
    case declined
    case noAnswer
    case server(String)

    var errorDescription: String? {
        switch self {
        case .missingAPIKey: "Add your Anthropic API key in Settings to search the web."
        case .invalidAPIKey: "The API key was rejected. Check it in Settings."
        case .busy: "The lookup service is busy right now. Try again in a minute."
        case .declined: "The lookup couldn't be completed for this search."
        case .noAnswer: "The lookup didn't return any results. Try a more specific name."
        case .server(let message): message
        }
    }
}

nonisolated struct CigarLookupService {
    private let endpoint = URL(string: "https://api.anthropic.com/v1/messages")!
    private let model = "claude-opus-5-5"
    private let maxContinuations = 3

    /// - Parameters:
    ///   - query: Whatever part of the name the user knows. May be empty when a photo is sent.
    ///   - photo: The cigar's photo, to help identify the line and pick the size.
    func lookUp(_ query: String, photo: Data? = nil) async throws -> CigarLookupResult {
        guard let apiKey = KeychainStore.anthropicAPIKey else { throw CigarLookupError.missingAPIKey }

        var content: [[String: Any]] = []
        if let photo, let jpeg = PhotoCompression.downsampledJPEG(from: photo, maxPixelSize: 1024) {
            content.append([
                "type": "image",
                "source": ["type": "base64", "media_type": "image/jpeg", "data": jpeg.base64EncodedString()]
            ])
        }
        let name = query.isEmpty ? "(not given; identify it from the photo)" : query
        content.append(["type": "text", "text": "Cigar: \(name)"])

        var messages: [[String: Any]] = [
            ["role": "user", "content": content]
        ]

        // Web search runs on Anthropic's servers; a long search can pause the turn,
        // in which case the paused response is sent back so it can resume.
        for _ in 0...maxContinuations {
            let response = try await send(messages: messages, apiKey: apiKey)
            let content = response["content"] as? [[String: Any]] ?? []

            if let input = content.first(where: { $0["type"] as? String == "tool_use" && $0["name"] as? String == "report_candidates" })?["input"] as? [String: Any] {
                return Self.parseCandidates(input)
            }

            switch response["stop_reason"] as? String {
            case "pause_turn":
                messages.append(["role": "assistant", "content": content])
            case "refusal":
                throw CigarLookupError.declined
            default:
                throw CigarLookupError.noAnswer
            }
        }
        throw CigarLookupError.noAnswer
    }

    // MARK: Request

    private func send(messages: [[String: Any]], apiKey: String) async throws -> [String: Any] {
        let body: [String: Any] = [
            "model": model,
            "max_tokens": 16000,
            "output_config": ["effort": "low"],
            "fallbacks": "default",
            "system": Self.systemPrompt,
            "tools": [
                ["type": "web_search_20260209", "name": "web_search", "max_uses": 3],
                Self.reportCandidatesTool
            ],
            "messages": messages
        ]

        var request = URLRequest(url: endpoint, timeoutInterval: 180)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "content-type")
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        request.setValue("server-side-fallback-2026-07-01", forHTTPHeaderField: "anthropic-beta")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, urlResponse) = try await URLSession.shared.data(for: request)
        let json = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] ?? [:]
        let status = (urlResponse as? HTTPURLResponse)?.statusCode ?? 0

        switch status {
        case 200:
            return json
        case 401, 403:
            throw CigarLookupError.invalidAPIKey
        case 429, 500...:
            throw CigarLookupError.busy
        default:
            let message = (json["error"] as? [String: Any])?["message"] as? String
            throw CigarLookupError.server(message ?? "Lookup failed (HTTP \(status)).")
        }
    }

    private static let systemPrompt = """
        You look up cigars for a personal cigar journal. The user types whatever they remember \
        of a cigar's name: sometimes only a brand ("Acid", "H. Upmann"), sometimes a line, \
        sometimes the exact cigar. Search the web (retailer and manufacturer pages list each \
        cigar's size, shape and strength), then report matching real cigars by calling \
        report_candidates exactly once.

        - If the query is only a brand, return its best-known lines with one or two popular \
        sizes each. Don't guess a single cigar.
        - If it names a line, return that line's sizes (vitolas).
        - If it identifies one cigar, return it first, followed by its other sizes.
        - Return at most 10 candidates, most likely first.
        - Only report sizes and strength stated on the pages you found; use null when a value \
        isn't stated. Never estimate.
        - Also report the tobacco when the pages state it: wrapper (e.g. "Ecuadorian \
        Habano", "San Andrés Maduro"), binder, filler (e.g. "Nicaragua, Dominican Republic") and \
        origin (the country where it's made). Keep each short; use null when not stated.
        - Map strength to Mild, Medium or Strong (mild-medium is Medium; medium-full and full are Strong).
        - If nothing matches, call report_candidates with an empty list and say why in note.

        The user may attach a photo of the cigar they smoked:
        - Read the band (brand, line and any secondary band text) and note the band colors \
        and wrapper shade; use them to narrow down the line, even when the typed name is vague.
        - Use the photo to judge which of the line's real sizes it is. You can't measure \
        inches from a photo, but you can compare proportions: length against thickness, the \
        band's width against the cigar, and the cigar against the hand holding it (an adult \
        finger is roughly 0.7 inches wide). A short, thick cigar is a robusto or gordo; a long, \
        thin one is a lonsdale or lancero.
        - Put the sizes that fit the photo first and set matchesPhoto to true for them; set it \
        to false for sizes the photo rules out, and for every candidate when there's no photo.
        - Sizes still come only from the pages you found. Never report a size just because the \
        photo suggests it.
        """

    private static var reportCandidatesTool: [String: Any] {
        [
            "name": "report_candidates",
            "description": "Report the cigars that match the user's search. Call exactly once, after searching.",
            "strict": true,
            "input_schema": [
                "type": "object",
                "additionalProperties": false,
                "required": ["note", "candidates"],
                "properties": [
                    "note": [
                        "type": "string",
                        "description": "One short sentence for the user, e.g. \"Acid is a brand; here are its best-known lines.\""
                    ],
                    "candidates": [
                        "type": "array",
                        "items": [
                            "type": "object",
                            "additionalProperties": false,
                            "required": ["name", "line", "vitola", "lengthInches", "ringGauge", "shape", "strength", "wrapper", "binder", "filler", "origin", "sourceURL", "matchesPhoto"],
                            "properties": [
                                "name": ["type": "string", "description": "Full name as commonly written, e.g. \"Acid Kuba Kuba\" or \"H. Upmann Vintage Cameroon Robusto\"."],
                                "line": ["type": "string", "description": "Brand and line, used for grouping, e.g. \"Acid Classic\"."],
                                "vitola": ["type": "string", "description": "The size's name, e.g. \"Robusto\" or \"Kuba Kuba\"."],
                                "lengthInches": ["anyOf": [["type": "number"], ["type": "null"]], "description": "Length in inches, e.g. 6.125 for 6 1/8."],
                                "ringGauge": ["anyOf": [["type": "integer"], ["type": "null"]]],
                                "shape": [
                                    "anyOf": [["type": "string", "enum": CigarTemplate.typeOptions], ["type": "null"]],
                                    "description": "The closest standard shape for this size."
                                ],
                                "strength": ["anyOf": [["type": "string", "enum": ["Mild", "Medium", "Strong"]], ["type": "null"]]],
                                "wrapper": ["anyOf": [["type": "string"], ["type": "null"]], "description": "Wrapper leaf, e.g. \"Ecuadorian Habano\"."],
                                "binder": ["anyOf": [["type": "string"], ["type": "null"]]],
                                "filler": ["anyOf": [["type": "string"], ["type": "null"]], "description": "Filler countries or leaf, e.g. \"Nicaragua, Dominican Republic\"."],
                                "origin": ["anyOf": [["type": "string"], ["type": "null"]], "description": "Country where the cigar is made."],
                                "sourceURL": ["type": "string", "description": "The page these details came from."],
                                "matchesPhoto": ["type": "boolean", "description": "True when this size looks consistent with the cigar in the photo."]
                            ]
                        ]
                    ]
                ]
            ]
        ]
    }

    // MARK: Response

    private static func nonEmpty(_ value: Any?) -> String? {
        guard let text = (value as? String)?.trimmingCharacters(in: .whitespacesAndNewlines), !text.isEmpty else { return nil }
        return text
    }

    private static func parseCandidates(_ input: [String: Any]) -> CigarLookupResult {
        let rawCandidates = input["candidates"] as? [[String: Any]] ?? []
        let candidates = rawCandidates.compactMap { raw -> CigarLookupCandidate? in
            guard let name = (raw["name"] as? String)?.trimmingCharacters(in: .whitespaces), !name.isEmpty else {
                return nil
            }
            return CigarLookupCandidate(
                name: name,
                line: raw["line"] as? String ?? name,
                vitola: raw["vitola"] as? String ?? "",
                lengthInches: (raw["lengthInches"] as? NSNumber)?.doubleValue,
                ringGauge: (raw["ringGauge"] as? NSNumber)?.intValue,
                shape: raw["shape"] as? String,
                strength: raw["strength"] as? String,
                wrapper: nonEmpty(raw["wrapper"]),
                binder: nonEmpty(raw["binder"]),
                filler: nonEmpty(raw["filler"]),
                origin: nonEmpty(raw["origin"]),
                sourceURL: (raw["sourceURL"] as? String).flatMap(URL.init(string:)),
                matchesPhoto: raw["matchesPhoto"] as? Bool ?? false
            )
        }
        return CigarLookupResult(candidates: candidates, note: input["note"] as? String ?? "")
    }
}
