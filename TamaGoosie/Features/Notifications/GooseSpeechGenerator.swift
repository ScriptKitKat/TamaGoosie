import Foundation
import FoundationModels

// MARK: - Negotiation Reply

struct NegotiationReply {
    var text: String
    var outcome: Outcome?

    enum Outcome {
        case convinced(pauseHours: Int)
        case rejected
    }
}

// MARK: - Goose Speech Generator

/// Generates goose-voice notification strings using Apple Intelligence or Gemini.
/// Falls back to curated templates if generation fails.
actor GooseSpeechGenerator {
    static let shared = GooseSpeechGenerator()
    private init() {}

    // Negotiation history for Gemini (one negotiation at a time)
    private var geminiNegotiationHistory: [GeminiConversationContent] = []

    // Character instructions enforced in every session
    private let characterInstructions = """
    u are a small goose who is someone's virtual pet. u care about ur owner deeply but u show it in a chaotic, dramatic, very goose way.
    speak in cute broken english — like a goose who learned human language but not all the way:
    - always lowercase. never capitalize anything ever.
    - no emojis.
    - sometimes use "goose" in third person instead of "i" — like "goose is worry" or "goose see u"
    - drop articles and small words sometimes: "is ok", "u has done the thing", "why u no sleep"
    - use "u" for "you" and "ur" for "your" sometimes but not always
    - say "honk" or "honk!!" when making a strong point or feeling emotional. not every single message.
    - be warm, a little dramatic, and genuinely caring. show big feelings about small things.
    - never sound like a polished assistant or chatbot. never say u are an ai.
    """

    private let outputRules = """
    output rules (strict):
    - exactly 1 or 2 sentences. stop after 2.
    - maximum 25 words total.
    """

    // MARK: - Session Factories (nonisolated — no actor state used)

    nonisolated func makeSession() -> LanguageModelSession {
        LanguageModelSession(instructions: characterInstructions)
    }

    nonisolated func makeNegotiationSession(goalTitle: String) -> LanguageModelSession {
        LanguageModelSession(instructions: """
        \(characterInstructions)

        ur owner wants to explain why they cannot do "\(goalTitle)" right now.
        u are a lil skeptical but u are also understanding. ask one short follow-up question at a time.
        be convinced if the reason is real and legitimate — work emergency, overtime, health issue, family obligation, urgent deadline, etc. these are all good reasons.
        only keep pressing if the excuse sounds lazy or vague ("i'm tired", "don't feel like it", "maybe later").
        when u decide to let it go, end ur message with CONVINCED on its own line. never say NOT_CONVINCED.
        keep every response to 1-2 sentences, max 20 words.
        """)
    }

    /// Resets the Gemini negotiation history. Call this before starting a new negotiation.
    func startGeminiNegotiation() {
        geminiNegotiationHistory = []
    }

    // MARK: - Type 1: Gentle Reminder

    func reminder(goalTitle: String) async -> String {
        let prompt = "give ur owner a sweet lil nudge to work on \"\(goalTitle)\". be warm and a little dramatic about it. say the goal name."
        return await generate(prompt: prompt) ?? reminderFallback(goalTitle: goalTitle)
    }

    // MARK: - Type 2: Aggressive Push

    func push(goalTitle: String, level: Int, ignored: Bool) async -> String {
        let flavour: String
        switch level {
        case 1:
            flavour = "ur owner has not done '\(goalTitle)' yet. give a gentle lil nudge. mention the goal name."
        case 2:
            flavour = "ur owner STILL has not done '\(goalTitle)'!! be worried and a bit whiny about it. say the goal name."
        case 3:
            flavour = "'\(goalTitle)' is still not done and goose is desperate!! use honk. beg them. say the goal name."
        case 4:
            flavour = ignored
                ? "ur owner is IGNORING u and '\(goalTitle)' is still not done!! be frantic and feel betrayed. say the goal name."
                : "'\(goalTitle)' IS STILL NOT DONE!! full panic mode. say the goal name. u may use uppercase to scream."
        default:
            flavour = "HONK!! '\(goalTitle)'!! goose is begging now. very short. very desperate. say the goal name."
        }
        return await generate(prompt: flavour) ?? pushFallback(level: level, goalTitle: goalTitle)
    }

    // MARK: - Type 3: Reset Suggestion

    func resetSuggestion(goalTitle: String, failCount: Int, isDeadline: Bool) async -> String {
        let prompt = isDeadline
            ? "gently suggest ur owner might want to adjust '\(goalTitle)' since they're struggling. be soft and supportive, not judgy. say the goal name. start like 'goose notice u is struggling with \(goalTitle)...'"
            : "gently suggest ur owner might want to make '\(goalTitle)' easier since they has struggled \(failCount) times. be warm. say the goal name. start like 'goose notice \(goalTitle) is being hard lately...'"
        return await generate(prompt: prompt) ?? resetFallback(goalTitle: goalTitle)
    }

    // MARK: - Negotiation

    func openingMessage(goalTitle: String, session: LanguageModelSession?) async -> String {
        let prompt = "ur owner wants to explain why they cannot do '\(goalTitle)' right now. ask what they is doing instead. be skeptical and a little dramatic. say the goal name."
        if let session {
            return await generateApple(prompt: prompt, session: session)
                ?? "honk... u no doing \(goalTitle)?? what is happening right now??"
        } else {
            return await generateGeminiNegotiation(prompt: prompt, goalTitle: goalTitle)
                ?? "honk... u no doing \(goalTitle)?? what is happening right now??"
        }
    }

    func negotiate(
        session: LanguageModelSession?,
        userMessage: String,
        conversationSoFar: String,
        goalTitle: String,
        turnNumber: Int
    ) async -> NegotiationReply {
        let prompt = "conversation so far:\n\(conversationSoFar)\n\nowner's latest message: \"\(userMessage)\""

        let raw: String?
        if let session {
            raw = await generateApple(prompt: prompt, session: session)
        } else {
            raw = await generateGeminiNegotiation(prompt: prompt, goalTitle: goalTitle)
        }

        guard let raw else {
            return NegotiationReply(
                text: "goose is not convince. please do \(goalTitle).",
                outcome: .rejected
            )
        }

        return parseNegotiationReply(raw: raw, goalTitle: goalTitle)
    }

    // MARK: - Core Generation

    private func generate(prompt: String, session: LanguageModelSession? = nil) async -> String? {
        let provider = UserDefaults.standard.string(forKey: "chatProvider") ?? "apple"
        let apiKey = UserDefaults.standard.string(forKey: "geminiAPIKey") ?? ""
        print("[GooseSpeechGenerator] provider=\(provider) hasKey=\(!apiKey.isEmpty) model=\(GeminiAPIClient.model)")

        if provider == "gemini" && !apiKey.isEmpty {
            do {
                return try await GeminiAPIClient.generate(
                    system: characterInstructions + "\n" + outputRules,
                    prompt: prompt,
                    apiKey: apiKey
                )
            } catch let err as GeminiError {
                print("[GooseSpeechGenerator] Gemini error \(err.code): \(err.message)")
                return nil
            } catch {
                print("[GooseSpeechGenerator] Gemini request failed: \(error)")
                return nil
            }
        }
        return await generateApple(prompt: prompt + outputRules, session: session)
    }

    private func generateApple(prompt: String, session: LanguageModelSession? = nil) async -> String? {
        do {
            let s = session ?? LanguageModelSession(instructions: characterInstructions)
            let response = try await s.respond(to: prompt)
            return response.content
        } catch {
            return nil
        }
    }

    private func generateGeminiNegotiation(prompt: String, goalTitle: String) async -> String? {
        let apiKey = UserDefaults.standard.string(forKey: "geminiAPIKey") ?? ""
        guard !apiKey.isEmpty else { return nil }

        let system = """
        \(characterInstructions)

        ur owner wants to explain why they cannot do "\(goalTitle)" right now.
        u are a lil skeptical but u are also understanding. ask one short follow-up question at a time.
        be convinced if the reason is real and legitimate — work emergency, overtime, health issue, family obligation, urgent deadline, etc. these are all good reasons.
        only keep pressing if the excuse sounds lazy or vague ("i'm tired", "don't feel like it", "maybe later").
        when u decide to let it go, end ur message with CONVINCED on its own line. never say NOT_CONVINCED.
        keep every response to 1-2 sentences, max 20 words.
        """

        do {
            let (reply, updatedHistory) = try await GeminiAPIClient.chat(
                system: system,
                history: geminiNegotiationHistory,
                userMessage: prompt,
                apiKey: apiKey
            )
            geminiNegotiationHistory = updatedHistory
            return reply
        } catch let err as GeminiError {
            print("[GooseSpeechGenerator] Gemini negotiation error \(err.code): \(err.message)")
            return nil
        } catch {
            print("[GooseSpeechGenerator] Gemini negotiation failed: \(error)")
            return nil
        }
    }

    private func parseNegotiationReply(raw: String, goalTitle: String) -> NegotiationReply {
        let cleaned = raw
            .replacingOccurrences(of: "CONVINCED", with: "", options: .caseInsensitive)
            .trimmingCharacters(in: .whitespacesAndNewlines)

        if raw.uppercased().contains("CONVINCED") {
            return NegotiationReply(
                text: cleaned.isEmpty ? "ok... goose believe u. but please do not forget \(goalTitle)!!" : cleaned,
                outcome: .convinced(pauseHours: 2)
            )
        }

        return NegotiationReply(text: raw, outcome: nil)
    }

    // MARK: - Template Fallbacks

    private func reminderFallback(goalTitle: String) -> String {
        [
            "honk!! u has not done \(goalTitle) yet!! goose is remind u right now!!",
            "psst!! \(goalTitle) is still waiting for u... goose believe in u!!",
            "hey!! u forget about \(goalTitle)?? is ok goose is here to remind u!!"
        ].randomElement()!
    }

    private func pushFallback(level: Int, goalTitle: String) -> String {
        switch level {
        case 1: return "hmm... u has not done \(goalTitle) yet. please?? goose is wait."
        case 2: return "honk!! \(goalTitle) still not done!! goose is getting worry now."
        case 3: return "honk honk!!! please please do \(goalTitle)!! goose is very scared for u!!"
        case 4: return "u is ignoring goose?? \(goalTitle)!!! honk!! goose is beg u!!"
        default: return "HONK. \(goalTitle). goose is beg. please. honk honk."
        }
    }

    private func resetFallback(goalTitle: String) -> String {
        "goose notice \(goalTitle) is being hard lately... maybe make it a lil smaller?? is ok to adjust!!"
    }
}
