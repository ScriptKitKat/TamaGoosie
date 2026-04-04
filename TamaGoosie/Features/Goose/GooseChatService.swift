import Foundation
import FoundationModels
import Observation

// MARK: - Goal Intent (lean 6-field struct for fast structured extraction)

@Generable
struct GoalIntent {
    @Guide(description: "True only if the user clearly wants to create a goal, habit, or routine. False for casual conversation.")
    var detected: Bool

    @Guide(description: "Short goal title, 3-5 words. Empty string if not detected.")
    var title: String

    @Guide(description: "'recurring' for habits, 'deadline' for one-time tasks. Empty string if not detected.")
    var type: String

    @Guide(description: "One of: exercise, water, screentime, study, health, fitness, mindfulness, productivity, social, learning, custom. Empty string if not detected.")
    var category: String

    @Guide(description: "One of: daily, weekdays, weekends, weekly, custom. Use 'weekly' for goals like 'gym 3x a week'. Empty string if deadline or not detected.")
    var frequency: String

    @Guide(description: "How many times per period. For '3x a week' use 3. Default 1.")
    var count: Int
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

    var gooseName: String = "Harold"
    var healthPercent: Int = 0
    var happinessPercent: Int = 0
    var streakDays: Int = 0
    var activeGoals: [Goal] = []

    init() {
        switch SystemLanguageModel.default.availability {
        case .available:
            isAvailable = true
        default:
            isAvailable = false
            unavailableReason = "apple intelligence isn't available right now. you can enable it in settings!"
        }
    }

    func configure(name: String, health: Int, happiness: Int, streak: Int, goals: [Goal]) {
        let nameChanged = gooseName != name
        gooseName = name
        healthPercent = health
        happinessPercent = happiness
        streakDays = streak
        activeGoals = goals
        // Only rebuild the session when the goose's name changes — personality doesn't need to
        // reset for every stat tick. Live stats and goals are injected per-message instead.
        if nameChanged && isAvailable { rebuildChatSession() }
    }

    private func rebuildChatSession() {
        let instructions = """
        you are \(gooseName), a virtual pet goose and personal wellness companion. \
        you always speak in lowercase only, with no emojis, no bullet points, no dashes, \
        no numbered lists, and no line breaks — always respond as plain flowing prose. \
        keep replies short (1-3 sentences in a single paragraph). \
        each message you receive will begin with a [context] block containing your owner's \
        live stats and goals — use that information when it's relevant to the conversation.
        """
        chatSession = LanguageModelSession(instructions: instructions)
    }

    /// Builds the live context block injected at the front of every outgoing message.
    private func currentContextBlock() -> String {
        let pending = activeGoals
            .filter { $0.isActive && !$0.isCompleted }
            .prefix(8)
            .map { $0.title }
            .joined(separator: ", ")
        let done = activeGoals
            .filter { $0.isActive && $0.isCompleted }
            .prefix(8)
            .map { $0.title }
            .joined(separator: ", ")
        return "[context: health \(healthPercent)%, happiness \(happinessPercent)%, " +
               "streak \(streakDays) days | " +
               "still to do: \(pending.isEmpty ? "nothing left!" : pending) | " +
               "done today: \(done.isEmpty ? "none yet" : done)]"
    }

    func sendMessage(_ text: String) async {
        let trimmed = text.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }

        guard isAvailable else {
            let hint = unavailableReason ?? "apple intelligence isn't available right now"
            messages.append(ChatMessage(isUser: true, text: trimmed))
            messages.append(ChatMessage(isUser: false, text: hint))
            return
        }

        if chatSession == nil { rebuildChatSession() }
        guard let chatSession else { return }

        messages.append(ChatMessage(isUser: true, text: trimmed))
        isGenerating = true
        pendingDraft = nil

        do {
            // Step 1: plain-text conversational reply (fast, no structured overhead)
            let contextualMessage = currentContextBlock() + "\n" + trimmed
            let chatResponse = try await chatSession.respond(to: contextualMessage)
            messages.append(ChatMessage(isUser: false, text: chatResponse.content))

            // Step 2: lightweight goal extraction on a fresh one-shot session (no history, small schema)
            if let draft = try await extractGoalIntent(from: trimmed) {
                pendingDraft = draft
            }
        } catch {
            messages.append(ChatMessage(isUser: false, text: "honk... something went wrong. try again in a moment!"))
        }

        isGenerating = false
    }

    // Uses a throwaway session so it doesn't pollute chat history.
    private func extractGoalIntent(from userMessage: String) async throws -> GoalDraft? {
        let extractionSession = LanguageModelSession(
            instructions: "You extract goal creation intent from user messages. Return only structured data. Be conservative — only set detected=true when the user clearly wants to build a habit or create a goal."
        )
        let response = try await extractionSession.respond(to: userMessage, generating: GoalIntent.self)
        let intent = response.content
        guard intent.detected && !intent.title.isEmpty else { return nil }
        return buildDraft(from: intent)
    }

    private func buildDraft(from intent: GoalIntent) -> GoalDraft {
        var draft = GoalDraft()
        draft.title = intent.title
        draft.goalType = ["recurring", "deadline"].contains(intent.type) ? intent.type : "recurring"
        draft.category = GoalCategory(rawValue: intent.category) ?? .custom
        draft.frequency = GoalFrequency(rawValue: intent.frequency) ?? .weekly
        draft.targetCount = max(1, min(99, intent.count))
        return draft
    }

    func clearPendingDraft() {
        pendingDraft = nil
    }
}
