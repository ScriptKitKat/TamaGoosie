import SwiftUI
import SwiftData

struct GoalEditorView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    var existingGoal: Goal?
    var prefill: GoalDraft?

    @State private var targetCount: Int

    init(existingGoal: Goal? = nil, prefill: GoalDraft? = nil) {
        self.existingGoal = existingGoal
        self.prefill = prefill
        _targetCount = State(initialValue: existingGoal?.targetCount ?? 1)
    }

    private var isBuiltin: Bool { existingGoal?.type == "builtin" }

    var body: some View {
        if isBuiltin {
            builtinEditor
        } else if let goal = existingGoal {
            GoalEditFormView(goal: goal)
        } else {
            GoalCreateFlowView(prefill: prefill)
        }
    }

    // MARK: - Built-in Threshold Editor

    private var builtinEditor: some View {
        NavigationStack {
            ZStack {
                GoosieTheme.mintBackground.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 20) {
                        GoosieCard {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Goal")
                                    .font(GoosieTheme.captionFont())
                                    .foregroundStyle(GoosieTheme.charcoalOutline.opacity(0.6))
                                Text(existingGoal?.title ?? "")
                                    .font(GoosieTheme.bodyFont())
                                    .foregroundStyle(GoosieTheme.charcoalOutline)
                            }
                        }

                        GoosieCard {
                            VStack(alignment: .leading, spacing: 8) {
                                Text(builtinEditorLabel)
                                    .font(GoosieTheme.captionFont())
                                    .foregroundStyle(GoosieTheme.charcoalOutline.opacity(0.6))
                                Stepper(value: $targetCount, in: builtinEditorRange, step: builtinEditorStep) {
                                    Text(builtinEditorValueLabel)
                                        .font(GoosieTheme.bodyFont())
                                        .foregroundStyle(GoosieTheme.charcoalOutline)
                                }
                            }
                        }
                    }
                    .padding(GoosieTheme.padding)
                }
            }
            .navigationTitle("Edit Goal Target")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { saveBuiltin() }
                }
            }
            .preferredColorScheme(.light)
        }
    }

    // MARK: - Built-in Helpers

    private enum BuiltinGoalKind {
        case steps, sleep, exercise, outside, screentime
    }

    private var builtinKind: BuiltinGoalKind {
        let t = existingGoal?.title ?? ""
        if t.localizedCaseInsensitiveContains("steps") || t.localizedCaseInsensitiveContains("walk") {
            return .steps
        } else if t.localizedCaseInsensitiveContains("sleep") {
            return .sleep
        } else if t.localizedCaseInsensitiveContains("exercise") {
            return .exercise
        } else if t.localizedCaseInsensitiveContains("outside") || t.localizedCaseInsensitiveContains("daylight") {
            return .outside
        } else {
            return .screentime
        }
    }

    private var builtinEditorLabel: String {
        switch builtinKind {
        case .steps: "Daily step target"
        case .sleep: "Sleep target (hours)"
        case .exercise: "Exercise target (minutes)"
        case .outside: "Outside time target (minutes)"
        case .screentime: "Screen time limit (minutes)"
        }
    }

    private var builtinEditorRange: ClosedRange<Int> {
        switch builtinKind {
        case .steps: 1000...50000
        case .sleep: 4...12
        case .exercise: 10...120
        case .outside: 10...180
        case .screentime: 30...480
        }
    }

    private var builtinEditorStep: Int {
        switch builtinKind {
        case .steps: 500
        case .sleep: 1
        case .exercise: 5
        case .outside: 5
        case .screentime: 15
        }
    }

    private var builtinEditorValueLabel: String {
        switch builtinKind {
        case .steps: "\(targetCount.formatted()) steps"
        case .sleep: "\(targetCount) hours"
        case .exercise: "\(targetCount) minutes"
        case .outside: "\(targetCount) minutes"
        case .screentime: "\(targetCount) minutes"
        }
    }

    private func saveBuiltin() {
        guard let goal = existingGoal else { return }
        goal.targetCount = targetCount
        try? modelContext.save()
        let descriptor = FetchDescriptor<Goal>(sortBy: [SortDescriptor(\.sortOrder)])
        if let allGoals = try? modelContext.fetch(descriptor) {
            let activeGoals = allGoals.filter { $0.isActive }
            ConvexManager.shared.syncGoals(goals: activeGoals)
        }
        dismiss()
    }
}
