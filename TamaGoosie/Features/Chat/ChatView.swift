import SwiftUI
import SwiftData

struct ChatView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var gooseStates: [GooseState]
    @Query(sort: \Goal.sortOrder) private var allGoals: [Goal]

    @State private var chatService = GooseChatService()
    @State private var goalViewModel = GoalViewModel()

    private var gooseState: GooseState {
        gooseStates.first ?? GooseState()
    }

    private var activeGoals: [Goal] { allGoals.filter { $0.isActive } }

    var body: some View {
        ZStack {
            GoosieTheme.mintBackground
                .ignoresSafeArea()

            GooseChatPanel(service: chatService) { draft in
                goalViewModel.pendingDraft = draft
                goalViewModel.editingGoal = nil
                goalViewModel.showEditor = true
            }
            .padding(.horizontal, GoosieTheme.padding)
            .padding(.vertical, 8)
        }
        .sheet(isPresented: $goalViewModel.showEditor) {
            GoalEditorView(existingGoal: goalViewModel.editingGoal, prefill: goalViewModel.pendingDraft)
        }
        .onAppear {
            chatService.refreshAvailability()
            syncChatService()
        }
        .onChange(of: gooseStates) { _, newStates in
            if newStates.first != nil {
                syncChatService()
            }
        }
        .onChange(of: allGoals) { _, _ in
            syncChatService()
        }
    }

    private func syncChatService() {
        let state = gooseState
        chatService.configure(
            name: state.name,
            health: Int(state.healthiness * 100),
            happiness: Int(state.happiness * 100),
            streak: state.streakDays,
            goals: activeGoals
        )
    }
}
