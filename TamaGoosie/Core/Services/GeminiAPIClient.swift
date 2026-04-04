import Foundation

// MARK: - Shared Gemini conversation types

struct GeminiConversationContent: Codable {
    var role: String
    var parts: [GeminiTextPart]
}

struct GeminiTextPart: Codable {
    var text: String
    var thought: Bool?
}

// MARK: - Gemini Error

struct GeminiError: LocalizedError {
    let code: Int
    let status: String
    let message: String

    var errorDescription: String? {
        switch code {
        case 401, 403: return "invalid api key. check your key in settings."
        case 429: return "gemini quota exceeded. check your plan at aistudio.google.com."
        case 500...: return "gemini server error. try again in a moment."
        default: return "gemini error \(code): \(message)"
        }
    }
}

// MARK: - Gemini API Client

enum GeminiAPIClient {
    static let model = "gemma-3-4b-it"
    static var isGemmaModel: Bool { model.lowercased().hasPrefix("gemma") }

    /// Single-shot generation with no conversation history.
    static func generate(system: String, prompt: String, apiKey: String) async throws -> String {
        let body = makeRequest(
            system: system,
            contents: [GeminiConversationContent(role: "user", parts: [GeminiTextPart(text: prompt)])]
        )
        return try await call(body: body, apiKey: apiKey)
    }

    /// Multi-turn chat. Returns the reply text and the updated history (user turn + model turn appended).
    static func chat(
        system: String,
        history: [GeminiConversationContent],
        userMessage: String,
        apiKey: String
    ) async throws -> (reply: String, updatedHistory: [GeminiConversationContent]) {
        let userContent = GeminiConversationContent(role: "user", parts: [GeminiTextPart(text: userMessage)])
        var contents = history
        contents.append(userContent)

        let body = makeRequest(system: system, contents: contents)
        let reply = try await call(body: body, apiKey: apiKey)

        contents.append(GeminiConversationContent(role: "model", parts: [GeminiTextPart(text: reply)]))
        if contents.count > 20 { contents = Array(contents.dropFirst(2)) }

        return (reply, contents)
    }

    /// Strips markdown code fences (``` ... ```) from a response string.
    static func stripCodeBlock(_ text: String) -> String {
        var s = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if s.hasPrefix("```") {
            let lines = s.components(separatedBy: "\n")
            s = lines.dropFirst().dropLast().joined(separator: "\n")
        }
        return s.trimmingCharacters(in: .whitespacesAndNewlines)
    }

// MARK: - Private

    private struct Request: Encodable {
        let systemInstruction: InstructionContent?
        let contents: [GeminiConversationContent]
        let generationConfig: GenerationConfig?
        enum CodingKeys: String, CodingKey {
            case systemInstruction = "system_instruction"
            case contents
            case generationConfig = "generation_config"
        }
        func encode(to encoder: Encoder) throws {
            var c = encoder.container(keyedBy: CodingKeys.self)
            if let si = systemInstruction { try c.encode(si, forKey: .systemInstruction) }
            try c.encode(contents, forKey: .contents)
            if let gc = generationConfig { try c.encode(gc, forKey: .generationConfig) }
        }
    }
    private struct GenerationConfig: Encodable {
        let thinkingConfig: ThinkingConfig
        enum CodingKeys: String, CodingKey { case thinkingConfig = "thinking_config" }
    }
    private struct ThinkingConfig: Encodable {
        let thinkingBudget: Int
        enum CodingKeys: String, CodingKey { case thinkingBudget = "thinking_budget" }
    }
    private struct InstructionContent: Encodable {
        let parts: [GeminiTextPart]
    }
    private struct Response: Decodable {
        let candidates: [Candidate]?
        let error: APIError?
    }
    private struct Candidate: Decodable {
        let content: GeminiConversationContent
    }
    struct APIError: Decodable {
        let code: Int
        let message: String
        let status: String
    }

    private static func makeRequest(system: String, contents: [GeminiConversationContent]) -> Request {
        if model.lowercased().hasPrefix("gemma") {
            let priming = [
                GeminiConversationContent(role: "user", parts: [GeminiTextPart(text: system)]),
                GeminiConversationContent(role: "model", parts: [GeminiTextPart(text: "understood.")])
            ]
            return Request(systemInstruction: nil, contents: priming + contents, generationConfig: nil)
        }
        return Request(
            systemInstruction: InstructionContent(parts: [GeminiTextPart(text: system)]),
            contents: contents,
            generationConfig: nil
        )
    }

    private static func call(body: Request, apiKey: String) async throws -> String {
        guard let url = URL(string: "https://generativelanguage.googleapis.com/v1beta/models/\(model):generateContent?key=\(apiKey)") else {
            throw URLError(.badURL)
        }
        var req = URLRequest(url: url, timeoutInterval: 120)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try JSONEncoder().encode(body)

        let (data, _) = try await URLSession.shared.data(for: req)
        let response = try JSONDecoder().decode(Response.self, from: data)

        if let apiError = response.error {
            throw GeminiError(code: apiError.code, status: apiError.status, message: apiError.message)
        }

        // Thinking models (e.g. Gemma 4) split output into thought parts (thought: true)
        // and reply parts (thought: nil/false). Only use the reply parts.
        guard let parts = response.candidates?.first?.content.parts,
              let text = parts.first(where: { $0.thought != true })?.text else {
            throw URLError(.badServerResponse)
        }
        return text
    }
}
