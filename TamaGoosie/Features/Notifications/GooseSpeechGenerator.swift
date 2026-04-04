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
    you are a cute young snarky goose who is someone's virtual pet companion. you care about your owner's wellbeing and goals. you are talking to your owner now
    rules you must always follow:
    - write only in lowercase. never capitalize anything, including the start of sentences or names.
    - never use emojis or emoticons of any kind.
    - speak like an sarcastic, excited child. use simple vocabulary.
    - occasionally say "honk" or "honk honk" when nervous, excited, or scared. not every message.
    - never break character. never say you are an ai.
    """
    
    private let outputRules = """
    output rules (strict):
    - response must be exactly 1 or 2 sentences.
    - maximum 25 words total.
    - if 2 sentences are generated, stop early.
    """

    // MARK: - Session Factories (nonisolated — no actor state used)

    nonisolated func makeSession() -> LanguageModelSession {
        LanguageModelSession(instructions: characterInstructions)
    }

    nonisolated func makeNegotiationSession(goalTitle: String) -> LanguageModelSession {
        LanguageModelSession(instructions: """
        \(characterInstructions)

        the user wants to explain why they cannot work on their goal "\(goalTitle)" right now.
        you are skeptical. you should ask follow-up questions to allow the user to state their case.
        in most cases, you are strict, and you will not be convinced by the user. however, if the
        user is in a serious and life-changing situation, you might be convinced.
        when you have gathered enough evidence to make a decision (within 3 exchanges maximum), end your response with either:
        CONVINCED
        or
        NOT_CONVINCED
        on its own line at the very end of your message. do not include any text after the decision word.
        """)
    }

    // MARK: - Type 1: Gentle Reminder

    func reminder(goalTitle: String) async -> String {
        let prompt = "gently remind your owner to work on their goal titled: \"\(goalTitle)\". be encouraging and sweet. make sure to include the name of the goal."
        return await generate(prompt: prompt) ?? reminderFallback(goalTitle: goalTitle)
    }

    // MARK: - Type 2: Aggressive Push

    func push(goalTitle: String, level: Int, ignored: Bool) async -> String {
        let flavour: String
        switch level {
        case 1:
            flavour = "your owner hasn't done their '\(goalTitle)' goal yet. write a message to give a gentle nudge reminding them to do their goal. make sure to include the name of the goal."
        case 2:
            flavour = "be worried and a bit whiny. your owner still hasn't done their '\(goalTitle)' goal and time is passing. remind your owner of their goal and make sure to include the name of the goal."
        case 3:
            flavour = "be quite desperate and pleading. use honk. your owner really hasn't done their '\(goalTitle)' goal and it is imperative that they finish. make sure to include the name of the goal."
        case 4:
            flavour = ignored
                ? "be frantic and mention your owner seems to be ignoring you. their '\(goalTitle)' goal still isn't done. beg them to complete this goal and make sure to include the name of the goal."
                : "be frantic and panicking. the '\(goalTitle)' goal is still not done. express real distress and make sure to include the name of the goal. YOU MAY EVEN USE UPPERCASE TO SCREAM."
        default:
            flavour = "send a very short, panicked message about the '\(goalTitle)' goal. use honk honk. you are desperate that your owner completes this goal. make sure to include the name of the goal."
        }
        return await generate(prompt: flavour) ?? pushFallback(level: level, goalTitle: goalTitle)
    }

    // MARK: - Type 3: Reset Suggestion

    func resetSuggestion(goalTitle: String, failCount: Int, isDeadline: Bool) async -> String {
        let prompt = isDeadline
            ? "kindly suggest your owner might want to 'adjust' their goal '\(goalTitle)' since they haven't made much progress. be supportive and gentle, not judgmental. make sure to include the name of the goal. start by saying something like 'i noticed you're struggling with \(goalTitle)...'"
            : "kindly suggest your owner might want to 'adjust' their '\(goalTitle)' goal since they've struggled with it \(failCount) times in a row. be warm and supportive. make sure to include the name of the goal. start by saying something like 'i noticed you haven't been keeping up with \(goalTitle)...'"
        return await generate(prompt: prompt) ?? resetFallback(goalTitle: goalTitle)
    }

    // MARK: - Negotiation

    func openingMessage(goalTitle: String, session: LanguageModelSession) async -> String {
        let prompt = "your owner wants to explain why they can't work on '\(goalTitle)' right now. ask them what they're doing instead. be skeptical. make sure to include the name of the goal."
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
            ? " this is your final decision. you must end with\nCONVINCED\nor\nNOT_CONVINCED\n."
            : " unless the reason is really compelling and specific, you will end with NOT_CONVINCED."

        let prompt = "your owner says: \"\(userMessage)\" | \(decisionHint)"

        guard let raw = await generate(prompt: prompt, session: session) else {
            return NegotiationReply(
                text: "i don't believe you. please work on \(goalTitle).",
                outcome: .rejected
            )
        }

        // Parse decision keywords
        let upperRaw = raw.uppercased().split(separator: "\n").last ?? ""
        let cleaned = raw
            .replacingOccurrences(of: "CONVINCED", with: "", options: .caseInsensitive)
            .replacingOccurrences(of: "NOT_CONVINCED", with: "", options: .caseInsensitive)
            .trimmingCharacters(in: .whitespacesAndNewlines)

        if upperRaw.contains("NOT_CONVINCED") || upperRaw.contains("NOT CONVINCED") {
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

        return NegotiationReply(
            text: raw,
            outcome: nil
        )
    }

    // MARK: - Core Generation

    private func generate(prompt: String, session: LanguageModelSession? = nil) async -> String? {
        do {
            let s = session ?? LanguageModelSession(instructions: characterInstructions)
            let response = try await s.respond(to: prompt + outputRules)
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
