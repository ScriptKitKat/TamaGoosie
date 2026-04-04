import SwiftUI
import FoundationModels

// MARK: - Negotiation Session

@MainActor
final class NegotiationSession: ObservableObject {
    @Published var messages: [NegotiationMessage] = []
    @Published var isLoading = false
    @Published var outcome: NegotiationReply.Outcome? = nil

    private let llmSession: LanguageModelSession
    private let goalTitle: String
    private(set) var turnCount = 0

    init(goalTitle: String) {
        self.goalTitle = goalTitle
        self.llmSession = GooseSpeechGenerator.shared.makeNegotiationSession(goalTitle: goalTitle)
    }

    func start() async {
        isLoading = true
        let text = await GooseSpeechGenerator.shared.openingMessage(goalTitle: goalTitle, session: llmSession)
        messages.append(NegotiationMessage(role: .goose, text: text))
        isLoading = false
    }

    func send(userMessage: String) async {
        guard outcome == nil else { return }

        messages.append(NegotiationMessage(role: .user, text: userMessage))
        isLoading = true

        let reply = await GooseSpeechGenerator.shared.negotiate(
            session: llmSession,
            userMessage: userMessage,
            goalTitle: goalTitle,
            turnNumber: turnCount
        )
        turnCount += 1

        messages.append(NegotiationMessage(role: .goose, text: reply.text))
        isLoading = false

        if let o = reply.outcome {
            outcome = o
        } else if turnCount >= 3 {
            // Force rejection after 3 unanswered turns
            let finalText = "i have made up my mind. please work on \(goalTitle). i believe in you."
            messages.append(NegotiationMessage(role: .goose, text: finalText))
            outcome = .rejected
        }
    }
}

// MARK: - Message Model

struct NegotiationMessage: Identifiable {
    let id = UUID()
    let role: Role
    let text: String

    enum Role { case goose, user }
}

// MARK: - Pending Negotiation Model

struct PendingNegotiation: Identifiable {
    let id = UUID()
    let goalID: UUID
    let goalTitle: String
    let gooseName: String
}

// MARK: - Negotiation View

struct NegotiationView: View {
    let negotiation: PendingNegotiation
    @Environment(\.dismiss) private var dismiss

    @StateObject private var session: NegotiationSession
    @State private var userInput = ""
    @State private var scrollProxy: ScrollViewProxy? = nil

    init(negotiation: PendingNegotiation) {
        self.negotiation = negotiation
        _session = StateObject(wrappedValue: NegotiationSession(goalTitle: negotiation.goalTitle))
    }

    var body: some View {
        ZStack {
            Color.black.opacity(0.92)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // Header
                header
                    .padding(.horizontal, 20)
                    .padding(.top, 20)
                    .padding(.bottom, 12)

                Divider().background(Color.white.opacity(0.15))

                // Chat
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 12) {
                            ForEach(session.messages) { msg in
                                MessageBubble(message: msg)
                                    .id(msg.id)
                            }

                            if session.isLoading {
                                TypingIndicator()
                                    .id("typing")
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                    }
                    .onChange(of: session.messages.count) { _, _ in
                        scrollToBottom(proxy: proxy)
                    }
                    .onChange(of: session.isLoading) { _, _ in
                        scrollToBottom(proxy: proxy)
                    }
                }

                // Input or outcome banner
                if let outcome = session.outcome {
                    outcomeBanner(outcome)
                } else {
                    inputBar
                }
            }
        }
        .task {
            await session.start()
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: 12) {
            Text("🪿")
                .font(.system(size: 32))

            VStack(alignment: .leading, spacing: 2) {
                Text(negotiation.gooseName)
                    .font(.system(size: 17, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                Text("convince me you're busy")
                    .font(.system(size: 13, design: .rounded))
                    .foregroundStyle(.white.opacity(0.6))
            }

            Spacer()

            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 24))
                    .foregroundStyle(.white.opacity(0.4))
            }
        }
    }

    // MARK: - Input Bar

    private var inputBar: some View {
        HStack(spacing: 10) {
            TextField("explain yourself...", text: $userInput, axis: .vertical)
                .font(.system(size: 15, design: .rounded))
                .foregroundStyle(.white)
                .tint(.white)
                .lineLimit(1...4)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 20)
                        .fill(Color.white.opacity(0.12))
                )

            Button {
                let text = userInput.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !text.isEmpty, !session.isLoading else { return }
                userInput = ""
                Task { await session.send(userMessage: text) }
            } label: {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.system(size: 32))
                    .foregroundStyle(userInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                                     ? Color.white.opacity(0.25) : Color(hex: 0xB8E8D0))
            }
            .disabled(userInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || session.isLoading)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color.white.opacity(0.05))
    }

    // MARK: - Outcome Banner

    private func outcomeBanner(_ outcome: NegotiationReply.Outcome) -> some View {
        Group {
            switch outcome {
            case .convinced(let hours):
                VStack(spacing: 6) {
                    Text("ok. i trust you. honk.")
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                        .foregroundStyle(Color(hex: 0xB8E8D0))
                    Text("pushing paused for \(hours) hours")
                        .font(.system(size: 12, design: .rounded))
                        .foregroundStyle(.white.opacity(0.5))
                }
                .onAppear {
                    GooseNotificationSystem.shared.pausePushes(goalID: negotiation.goalID, hours: hours)
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { dismiss() }
                }

            case .rejected:
                VStack(spacing: 6) {
                    Text("i'm not convinced. please work on it.")
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                        .foregroundStyle(Color(hex: 0xFF6B6B))
                    Text("honk.")
                        .font(.system(size: 12, design: .rounded))
                        .foregroundStyle(.white.opacity(0.5))
                }
                .onAppear {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { dismiss() }
                }
            }
        }
        .padding(.vertical, 16)
        .frame(maxWidth: .infinity)
        .background(Color.white.opacity(0.08))
    }

    // MARK: - Helpers

    private func scrollToBottom(proxy: ScrollViewProxy) {
        withAnimation(.easeOut(duration: 0.2)) {
            if session.isLoading {
                proxy.scrollTo("typing", anchor: .bottom)
            } else if let last = session.messages.last {
                proxy.scrollTo(last.id, anchor: .bottom)
            }
        }
    }
}

// MARK: - Message Bubble

private struct MessageBubble: View {
    let message: NegotiationMessage

    var body: some View {
        HStack {
            if message.role == .user { Spacer(minLength: 60) }

            Text(message.text)
                .font(.system(size: 14, design: .rounded))
                .foregroundStyle(message.role == .goose ? Color.black.opacity(0.85) : Color.white)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 18)
                        .fill(message.role == .goose
                              ? Color(hex: 0xB8E8D0)   // mint — goose
                              : Color(hex: 0xFF6B6B).opacity(0.8))   // coral — user
                )

            if message.role == .goose { Spacer(minLength: 60) }
        }
    }
}

// MARK: - Typing Indicator

private struct TypingIndicator: View {
    @State private var phase = 0

    var body: some View {
        HStack(spacing: 5) {
            ForEach(0..<3) { i in
                Circle()
                    .fill(Color(hex: 0xB8E8D0))
                    .frame(width: 7, height: 7)
                    .scaleEffect(phase == i ? 1.3 : 0.8)
                    .animation(.easeInOut(duration: 0.4).repeatForever().delay(Double(i) * 0.15), value: phase)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(RoundedRectangle(cornerRadius: 18).fill(Color.white.opacity(0.1)))
        .onAppear { phase = 0; withAnimation { phase = 1 } }
    }
}
