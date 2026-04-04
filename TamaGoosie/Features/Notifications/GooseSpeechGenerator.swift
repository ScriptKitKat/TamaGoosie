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

/// Generates goose-voice notification strings using Apple Intelligence.
/// Falls back to curated templates if generation fails.
actor GooseSpeechGenerator {
    static let shared = GooseSpeechGenerator()
    private init() {}

    // Character instructions enforced in every session
    private let characterInstructions = """
    you are a young goose who is someone's beloved virtual pet companion. you care very deeply about your owner's wellbeing and goals.
    rules you must always follow:
    - write only in lowercase. never capitalize anything, including the start of sentences or names.
    - never use emojis or emoticons of any kind.
    - speak like an earnest, excited child. use simple vocabulary.
    - occasionally say "honk" or "honk honk" when nervous, excited, or scared. not every message.
    - keep every response to 2 sentences or fewer. be concise.
    - never break character. never say you are an ai.
    """

    // MARK: - Session Factories (nonisolated — no actor state used)

    nonisolated func makeSession() -> LanguageModelSession {
        LanguageModelSession(instructions: characterInstructions)
    }

    nonisolated func makeNegotiationSession(goalTitle: String) -> LanguageModelSession {
        LanguageModelSession(instructions: """
        \(characterInstructions)

        the user wants to explain why they cannot work on their goal "\(goalTitle)" right now.
        you are skeptical but fair. you can ask one follow-up question if needed.
        when you are ready to decide (within 3 exchanges maximum), end your response with either:
        CONVINCED
        or
        NOT_CONVINCED
        on its own line at the very end of your message. do not include any text after the decision word.
        """)
    }

    // MARK: - Type 1: Gentle Reminder

    func reminder(goalTitle: String) async -> String {
        let prompt = "gently remind your owner to work on their goal: \"\(goalTitle)\". be encouraging and sweet."
        return await generate(prompt: prompt) ?? reminderFallback(goalTitle: goalTitle)
    }

    // MARK: - Type 2: Aggressive Push

    func push(goalTitle: String, level: Int, ignored: Bool) async -> String {
        let flavour: String
        switch level {
        case 1:
            flavour = "give a gentle nudge. your owner hasn't done '\(goalTitle)' yet."
        case 2:
            flavour = "be worried and a bit whiny. your owner still hasn't done '\(goalTitle)' and time is passing."
        case 3:
            flavour = "be quite desperate and scared. use honk. your owner really hasn't done '\(goalTitle)'."
        case 4:
            flavour = ignored
                ? "be frantic and mention your owner seems to be ignoring you. '\(goalTitle)' still isn't done."
                : "be frantic and panicking. '\(goalTitle)' is still not done. express real distress."
        default:
            flavour = "send a very short, panicked message about '\(goalTitle)'. use honk honk. you are desperate."
        }
        return await generate(prompt: flavour) ?? pushFallback(level: level, goalTitle: goalTitle)
    }

    // MARK: - Type 3: Reset Suggestion

    func resetSuggestion(goalTitle: String, failCount: Int, isDeadline: Bool) async -> String {
        let prompt = isDeadline
            ? "kindly suggest your owner might want to adjust their goal '\(goalTitle)' since they haven't made much progress. be supportive and gentle, not judgmental."
            : "kindly suggest your owner might want to make '\(goalTitle)' a little easier since they've struggled with it \(failCount) times in a row. be warm and supportive."
        return await generate(prompt: prompt) ?? resetFallback(goalTitle: goalTitle)
    }

    // MARK: - Negotiation

    func openingMessage(goalTitle: String, session: LanguageModelSession) async -> String {
        let prompt = "your owner wants to explain why they can't work on '\(goalTitle)' right now. ask them what they're doing instead. be skeptical but polite."
        return await generate(prompt: prompt, session: session)
            ?? "honk... you're not doing \(goalTitle)? what is so important right now??"
    }

    func negotiate(
        session: LanguageModelSession,
        userMessage: String,
        goalTitle: String,
        turnNumber: Int
    ) async -> NegotiationReply {
        let decisionHint = turnNumber >= 2
            ? " this is your final decision. you must end with CONVINCED or NOT_CONVINCED."
            : " if the reason is really compelling and specific, you may end with CONVINCED."

        let prompt = "your owner says: \"\(userMessage)\"\(decisionHint)"

        guard let raw = await generate(prompt: prompt, session: session) else {
            return NegotiationReply(
                text: "ok... i guess i believe you. but please don't forget about \(goalTitle).",
                outcome: .convinced(pauseHours: 2)
            )
        }

        // Parse decision keywords
        let upperRaw = raw.uppercased()
        let cleaned = raw
            .replacingOccurrences(of: "CONVINCED", with: "", options: .caseInsensitive)
            .replacingOccurrences(of: "NOT_CONVINCED", with: "", options: .caseInsensitive)
            .trimmingCharacters(in: .whitespacesAndNewlines)

        if upperRaw.contains("NOT_CONVINCED") {
            return NegotiationReply(
                text: cleaned.isEmpty ? "i don't believe you. please work on \(goalTitle)." : cleaned,
                outcome: .rejected
            )
        } else if upperRaw.contains("CONVINCED") {
            return NegotiationReply(
                text: cleaned.isEmpty ? "ok... i trust you. honk. but don't forget about \(goalTitle)." : cleaned,
                outcome: .convinced(pauseHours: 2)
            )
        }

        return NegotiationReply(text: raw, outcome: nil)
    }

    // MARK: - Core Generation

    private func generate(prompt: String, session: LanguageModelSession? = nil) async -> String? {
        do {
            let s = session ?? LanguageModelSession(instructions: characterInstructions)
            let response = try await s.respond(to: prompt)
            return response.content
        } catch {
            return nil
        }
    }

    // MARK: - Template Fallbacks

    private func reminderFallback(goalTitle: String) -> String {
        [
            "hey!! don't forget about \(goalTitle) today. i believe in you.",
            "honk! just a little reminder... \(goalTitle) is waiting for you.",
            "psst... have you worked on \(goalTitle) yet? you can do it!"
        ].randomElement()!
    }

    private func pushFallback(level: Int, goalTitle: String) -> String {
        switch level {
        case 1: return "hey... you haven't done \(goalTitle) yet. please don't forget about it."
        case 2: return "honk!! you really need to do \(goalTitle). i'm starting to get worried."
        case 3: return "honk honk!!! please please please do \(goalTitle). i am very scared for you."
        case 4: return "why are you ignoring me?? i have been asking about \(goalTitle)!!! honk!!"
        default: return "HONK. \(goalTitle). i am begging. please. honk honk."
        }
    }

    private func resetFallback(goalTitle: String) -> String {
        "hey... maybe we could make \(goalTitle) a little easier? it is ok to adjust your goals."
    }
}
