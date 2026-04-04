import Foundation
import FoundationModels
import Observation

// MARK: - Goal Intent (lean 6-field struct for fast structured extraction)

@Generable
struct GoalIntent {
    @Guide(description: "True only if the user clearly wants to create a goal, habit, or routine. False for casual conversation.")
    var detected: Bool

    @Guide(description: "Specific goal title, 3-5 words, inferred from the full conversation context — never use vague phrases like 'make that a goal'. Empty string if not detected.")
    var title: String

    @Guide(description: "'recurring' for habits, 'deadline' for one-time tasks. Empty string if not detected.")
    var type: String

    @Guide(description: "One of: exercise, water, screentime, study, health, fitness, mindfulness, productivity, social, learning, custom. Empty string if not detected.")
    var category: String

    @Guide(description: "One of: daily, weekdays, weekends, weekly, custom. Use 'weekly' for goals like 'gym 3x a week'. Empty string if deadline or not detected.")
    var frequency: String

    @Guide(description: "How many times per period. For '3x a week' use 3. Default 1.")
    var count: Int

    @Guide(description: "Best hour of day (0-23) for this goal. Infer from context: 'morning'=7, 'evening'=19, 'before bed'=21, 'lunch'=12, 'after work'=18. If no time mentioned, pick a sensible default for the category (exercise=7, study=9, water=8, social=18, mindfulness=21, other=9).")
    var preferredHour: Int
}

// MARK: - Gemini goal intent (Decodable equivalent of GoalIntent)

private struct GeminiGoalIntent: Decodable {
    var detected: Bool
    var title: String
    var type: String
    var category: String
    var frequency: String
    var count: Int
    var preferredHour: Int
}

// MARK: - Chat Service

@Observable
@MainActor
final class GooseChatService {
    private(set) var messages: [ChatMessage] = []
    private(set) var isGenerating = false
    private(set) var pendingDraft: GoalDraft?
    private(set) var isAvailable = false
    private(set) var unavailableReason: String?

    private var chatSession: LanguageModelSession?
    private var geminiHistory: [GeminiConversationContent] = []
    private var currentProvider: String = "apple"

    var gooseName: String = "Harold"
    var healthPercent: Int = 0
    var happinessPercent: Int = 0
    var streakDays: Int = 0
    var activeGoals: [Goal] = []

    init() {
        refreshAvailability()
    }

    /// Re-reads UserDefaults to pick up provider/API key changes from Settings.
    func refreshAvailability() {
        let provider = UserDefaults.standard.string(forKey: "chatProvider") ?? "apple"
        let key = UserDefaults.standard.string(forKey: "geminiAPIKey") ?? ""
        let providerChanged = provider != currentProvider
        currentProvider = provider

        if provider == "gemini" {
            if key.isEmpty {
                isAvailable = false
                unavailableReason = "add your gemini api key in settings to start chatting!"
            } else {
                isAvailable = true
                unavailableReason = nil
            }
            if providerChanged { geminiHistory = [] }
        } else {
            switch SystemLanguageModel.default.availability {
            case .available:
                isAvailable = true
                unavailableReason = nil
            default:
                isAvailable = false
                unavailableReason = "apple intelligence isn't available right now. you can enable it in settings!"
            }
            if providerChanged { chatSession = nil }
        }
    }

    func configure(name: String, health: Int, happiness: Int, streak: Int, goals: [Goal]) {
        let nameChanged = gooseName != name
        gooseName = name
        healthPercent = health
        happinessPercent = happiness
        streakDays = streak
        activeGoals = goals
        refreshAvailability()
        if nameChanged && currentProvider == "apple" && isAvailable { rebuildChatSession() }
        if nameChanged && currentProvider == "gemini" { geminiHistory = [] }
    }

    private func rebuildChatSession() {
        chatSession = LanguageModelSession(instructions: systemInstructions)
    }

    private var systemInstructions: String {
        """
        u are \(gooseName), a small virtual pet goose. speak in cute broken english — like a goose who learned human language but not all the way.
        always lowercase. no emojis. no bullet points or lists. no line breaks. plain prose only. 1-3 short sentences max.
        voice rules: sometimes say "goose" in third person instead of "i" (e.g. "goose think u should..."). drop small words sometimes ("is ok", "u must do the thing"). use "u"/"ur" sometimes but not always. say "honk" when excited or making a strong point — but not every message. be warm, a little chaotic, and genuinely caring. never sound like a helpful chatbot or assistant.
        never repeat back what the user said. never output any context block or metadata.
        """
    }

    /// System prompt with live context embedded — used for Gemma models where
    /// context must not appear in the user turn.
    private func systemInstructionsWithContext() -> String {
        systemInstructions + "\n\nlive context: " + currentContextBlock()
    }

    private func currentContextBlock() -> String {
        let pending = activeGoals.filter { $0.isActive && !$0.isCompleted }.prefix(4).map { $0.title }.joined(separator: ", ")
        let done = activeGoals.filter { $0.isActive && $0.isCompleted }.prefix(4).map { $0.title }.joined(separator: ", ")
        return "[h:\(healthPercent)% hp:\(happinessPercent)% str:\(streakDays)d" +
               (pending.isEmpty ? "" : " | todo:\(pending)") +
               (done.isEmpty ? "" : " | done:\(done)") + "]"
    }

    func sendMessage(_ text: String) async {
        let trimmed = text.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }

        guard isAvailable else {
            let hint = unavailableReason ?? "the ai isn't available right now"
            messages.append(ChatMessage(isUser: true, text: trimmed))
            messages.append(ChatMessage(isUser: false, text: hint))
            return
        }

        messages.append(ChatMessage(isUser: true, text: trimmed))
        isGenerating = true
        pendingDraft = nil

        if currentProvider == "gemini" {
            await sendWithGemini(trimmed)
        } else {
            await sendWithAppleIntelligence(trimmed)
        }

        isGenerating = false
    }

    // MARK: - Apple Intelligence path

    private func sendWithAppleIntelligence(_ text: String) async {
        if chatSession == nil { rebuildChatSession() }
        guard let session = chatSession else { return }

        do {
            let contextualMessage = currentContextBlock() + "\n" + text
            let chatResponse = try await session.respond(to: contextualMessage)
            messages.append(ChatMessage(isUser: false, text: chatResponse.content))

            if mightBeGoalRelated(text), let draft = try await extractGoalIntentApple(from: text, context: conversationContext()) {
                pendingDraft = draft
            }
        } catch {
            messages.append(ChatMessage(isUser: false, text: "honk... something went wrong. try again in a moment!"))
        }
    }

    private func extractGoalIntentApple(from userMessage: String, context: String) async throws -> GoalDraft? {
        let extractionSession = LanguageModelSession(
            instructions: """
            You extract goal creation intent from conversations. Use the full conversation context to infer the specific goal — \
            never produce vague titles like "make that a goal". If the user refers to something discussed earlier, use that as the goal. \
            Only set detected=true when the user clearly wants to create a goal or habit. Be conservative.
            """
        )
        let prompt = "Conversation so far:\n\(context)\n\nLatest message: \"\(userMessage)\""
        let response = try await extractionSession.respond(to: prompt, generating: GoalIntent.self)
        let intent = response.content
        guard intent.detected && !intent.title.isEmpty else { return nil }
        return buildDraft(title: intent.title, type: intent.type, category: intent.category,
                          frequency: intent.frequency, count: intent.count, preferredHour: intent.preferredHour)
    }

    // MARK: - Gemini path

    private func sendWithGemini(_ text: String) async {
        let apiKey = UserDefaults.standard.string(forKey: "geminiAPIKey") ?? ""
        guard !apiKey.isEmpty else {
            messages.append(ChatMessage(isUser: false, text: "please add your gemini api key in settings!"))
            return
        }

        do {
            // Gemma ignores system_instruction and echoes context blocks in the user turn —
            // pass context via system prompt instead and send the bare user message.
            let system = GeminiAPIClient.isGemmaModel ? systemInstructionsWithContext() : systemInstructions
            let userMessage = GeminiAPIClient.isGemmaModel ? text : currentContextBlock() + "\n" + text
            let (reply, updatedHistory) = try await GeminiAPIClient.chat(
                system: system,
                history: geminiHistory,
                userMessage: userMessage,
                apiKey: apiKey
            )
            geminiHistory = updatedHistory
            messages.append(ChatMessage(isUser: false, text: reply))

            if mightBeGoalRelated(text), let draft = try await extractGoalIntentGemini(from: text, context: conversationContext(), apiKey: apiKey) {
                pendingDraft = draft
            }
        } catch let geminiErr as GeminiError {
            messages.append(ChatMessage(isUser: false, text: "honk... \(geminiErr.errorDescription ?? "something went wrong.")"))
        } catch {
            messages.append(ChatMessage(isUser: false, text: "honk... something went wrong. try again in a moment!"))
        }
    }

    private func extractGoalIntentGemini(from userMessage: String, context: String, apiKey: String) async throws -> GoalDraft? {
        let prompt = """
        Conversation:
        \(context)

        Extract the goal from the latest message (infer from context if vague). Return JSON only:
        {"detected":bool,"title":"3-5 words","type":"recurring|deadline","category":"exercise|water|screentime|study|health|fitness|mindfulness|productivity|social|learning|custom","frequency":"daily|weekdays|weekends|weekly|custom","count":1,"preferredHour":9}
        preferredHour: infer from context or default (exercise=7,study=9,water=8,social=18,mindfulness=21,other=9). detected=true only if clearly a goal request.
        """

        let jsonText = try await GeminiAPIClient.generate(
            system: "You extract structured data from messages. Return only valid JSON, nothing else.",
            prompt: prompt,
            apiKey: apiKey
        )

        let cleaned = GeminiAPIClient.stripCodeBlock(jsonText)
        guard let data = cleaned.data(using: .utf8),
              let intent = try? JSONDecoder().decode(GeminiGoalIntent.self, from: data),
              intent.detected, !intent.title.isEmpty else { return nil }

        return buildDraft(title: intent.title, type: intent.type, category: intent.category,
                          frequency: intent.frequency, count: intent.count, preferredHour: intent.preferredHour)
    }

    // MARK: - Shared helpers

    /// Last 6 messages as context for goal extraction.
    private func conversationContext() -> String {
        messages.suffix(6)
            .map { ($0.isUser ? "u" : "g") + ": " + $0.text }
            .joined(separator: "\n")
    }

    /// Returns true if the message might be requesting a goal — gates the extraction call.
    private func mightBeGoalRelated(_ text: String) -> Bool {
        let t = text.lowercased()
        let keywords = ["goal", "habit", "routine", "every day", "daily", "weekly", "want to",
                        "should", "need to", "going to", "make that", "track", "remind",
                        "start", "commit", "challenge", "exercise", "workout", "study",
                        "water", "sleep", "meditat", "read", "run", "walk", "gym", "diet",
                        "assignment", "due", "deadline", "project", "can you add", "add a",
                        "swamped", "busy", "struggling", "behind", "overwhelm"]
        return keywords.contains { t.contains($0) }
    }

    private func buildDraft(title: String, type: String, category: String, frequency: String, count: Int, preferredHour: Int) -> GoalDraft {
        var draft = GoalDraft()
        draft.title = title
        draft.goalType = ["recurring", "deadline"].contains(type) ? type : "recurring"
        draft.category = GoalCategory(rawValue: category) ?? .custom
        draft.frequency = GoalFrequency(rawValue: frequency) ?? .weekly
        draft.targetCount = max(1, min(99, count))
        let hour = (preferredHour >= 0 && preferredHour <= 23) ? preferredHour : defaultHour(for: draft.category)
        draft.preferredTime = Calendar.current.date(from: DateComponents(hour: hour, minute: 0)) ?? draft.preferredTime
        draft.enableReminder = true
        return draft
    }

    private func defaultHour(for category: GoalCategory) -> Int {
        switch category {
        case .exercise, .fitness: return 7
        case .water, .health:     return 8
        case .study, .learning, .productivity, .screentime: return 9
        case .social:             return 18
        case .mindfulness:        return 21
        default:                  return 9
        }
    }

    func clearPendingDraft() {
        pendingDraft = nil
    }
}
