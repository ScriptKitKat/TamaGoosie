import SwiftUI

struct GooseChatPanel: View {
    let service: GooseChatService
    let onGoalDraftReady: (GoalDraft) -> Void

    @State private var inputText = ""
    @FocusState private var isInputFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            panelHeader
            Divider().opacity(0.25)
            messagesArea
            Divider().opacity(0.25)
            inputRow
        }
        .background(GoosieTheme.creamWhite)
        .clipShape(RoundedRectangle(cornerRadius: GoosieTheme.cornerRadius, style: .continuous))
        .shadow(color: GoosieTheme.charcoalOutline.opacity(0.07), radius: 10, y: -3)
    }

    // MARK: - Panel Header

    private var panelHeader: some View {
        HStack(spacing: 6) {
            Text("chat with \(service.gooseName.lowercased())")
                .font(GoosieTheme.captionFont(13))
                .foregroundStyle(GoosieTheme.charcoalOutline.opacity(0.55))
            Spacer()
            if service.isGenerating {
                ThinkingDots()
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 12)
        .padding(.bottom, 10)
    }

    // MARK: - Messages Area

    private var messagesArea: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 8) {
                    if service.messages.isEmpty {
                        emptyPrompt
                    } else {
                        ForEach(service.messages) { msg in
                            MessageBubble(message: msg)
                                .id(msg.id)
                        }
                    }

                    // Goal suggestion chip — only shown when the AI detected goal intent
                    if let draft = service.pendingDraft {
                        GoalSuggestionChip(draft: draft) {
                            onGoalDraftReady(draft)
                            service.clearPendingDraft()
                        } onDismiss: {
                            service.clearPendingDraft()
                        }
                        .id("goalChip")
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .animation(.easeOut(duration: 0.2), value: service.pendingDraft != nil)
            }
            .onChange(of: service.messages.count) { _, _ in
                withAnimation(.easeOut(duration: 0.2)) {
                    if service.pendingDraft != nil {
                        proxy.scrollTo("goalChip", anchor: .bottom)
                    } else if let last = service.messages.last {
                        proxy.scrollTo(last.id, anchor: .bottom)
                    }
                }
            }
            .onChange(of: service.pendingDraft) { _, draft in
                if draft != nil {
                    withAnimation(.easeOut(duration: 0.2)) {
                        proxy.scrollTo("goalChip", anchor: .bottom)
                    }
                }
            }
        }
    }

    private var emptyPrompt: some View {
        VStack(spacing: 6) {
            Text("honk honk!")
                .font(GoosieTheme.bodyFont(14))
                .foregroundStyle(GoosieTheme.charcoalOutline.opacity(0.45))
            Text("tell me what you want to work on today")
                .font(GoosieTheme.captionFont(12))
                .foregroundStyle(GoosieTheme.charcoalOutline.opacity(0.3))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
    }

    // MARK: - Input Row

    private var inputRow: some View {
        HStack(spacing: 10) {
            TextField("say something...", text: $inputText, axis: .vertical)
                .font(GoosieTheme.bodyFont(14))
                .lineLimit(1...3)
                .focused($isInputFocused)
                .submitLabel(.send)
                .onSubmit { sendMessage() }

            Button(action: sendMessage) {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.system(size: 30))
                    .foregroundStyle(canSend ? GoosieTheme.coralAccent : GoosieTheme.charcoalOutline.opacity(0.18))
            }
            .disabled(!canSend)
            .animation(.easeInOut(duration: 0.15), value: canSend)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }

    private var canSend: Bool {
        !inputText.trimmingCharacters(in: .whitespaces).isEmpty && !service.isGenerating
    }

    private func sendMessage() {
        let text = inputText.trimmingCharacters(in: .whitespaces)
        guard !text.isEmpty, !service.isGenerating else { return }
        inputText = ""
        isInputFocused = false
        Task { await service.sendMessage(text) }
    }
}

// MARK: - Goal Suggestion Chip

private struct GoalSuggestionChip: View {
    let draft: GoalDraft
    let onAdd: () -> Void
    let onDismiss: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: categoryIcon)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(GoosieTheme.coralAccent)

            VStack(alignment: .leading, spacing: 2) {
                Text(draft.title.isEmpty ? "new goal" : draft.title)
                    .font(GoosieTheme.bodyFont(13))
                    .foregroundStyle(GoosieTheme.charcoalOutline)
                Text(subtitleText)
                    .font(GoosieTheme.captionFont(11))
                    .foregroundStyle(GoosieTheme.charcoalOutline.opacity(0.5))
            }

            Spacer()

            Button(action: onAdd) {
                Text("add goal")
                    .font(GoosieTheme.captionFont(12))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Capsule().fill(GoosieTheme.coralAccent))
            }

            Button(action: onDismiss) {
                Image(systemName: "xmark")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(GoosieTheme.charcoalOutline.opacity(0.35))
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(GoosieTheme.coralAccent.opacity(0.08))
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .strokeBorder(GoosieTheme.coralAccent.opacity(0.25), lineWidth: 1)
                )
        )
    }

    private var categoryIcon: String {
        draft.category.icon
    }

    private var subtitleText: String {
        if draft.goalType == "deadline" {
            let days = Calendar.current.dateComponents([.day], from: .now, to: draft.dueDate).day ?? 0
            return days > 0 ? "due in \(days) days" : "deadline goal"
        }
        let freq = draft.frequency.displayName.lowercased()
        return draft.targetCount > 1 ? "\(draft.targetCount)x \(freq)" : freq
    }
}

// MARK: - Message Bubble

private struct MessageBubble: View {
    let message: ChatMessage

    var body: some View {
        HStack(alignment: .bottom, spacing: 0) {
            if message.isUser { Spacer(minLength: 44) }

            Text(message.text)
                .font(GoosieTheme.bodyFont(14))
                .foregroundStyle(message.isUser ? .white : GoosieTheme.charcoalOutline)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(message.isUser ? GoosieTheme.coralAccent : GoosieTheme.mintBackground)
                )
                .frame(maxWidth: .infinity, alignment: message.isUser ? .trailing : .leading)

            if !message.isUser { Spacer(minLength: 44) }
        }
    }
}

// MARK: - Thinking Dots Animation

private struct ThinkingDots: View {
    @State private var animating = false

    var body: some View {
        HStack(spacing: 3) {
            ForEach(0..<3, id: \.self) { i in
                Circle()
                    .fill(GoosieTheme.charcoalOutline.opacity(0.35))
                    .frame(width: 5, height: 5)
                    .offset(y: animating ? -3 : 0)
                    .animation(
                        .easeInOut(duration: 0.4)
                            .repeatForever(autoreverses: true)
                            .delay(Double(i) * 0.15),
                        value: animating
                    )
            }
        }
        .onAppear { animating = true }
        .onDisappear { animating = false }
    }
}
