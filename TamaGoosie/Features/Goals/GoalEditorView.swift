import SwiftUI
import SwiftData

struct GoalEditorView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    var existingGoal: Goal?

    @State private var title = ""
    @State private var category: GoalCategory = .custom
    @State private var frequency: GoalFrequency = .daily
    @State private var targetCount = 1

    var isEditing: Bool { existingGoal != nil }

    var body: some View {
        NavigationStack {
            ZStack {
                GoosieTheme.mintBackground
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 20) {
                        // Title
                        GoosieCard {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Goal Title")
                                    .font(GoosieTheme.captionFont())
                                    .foregroundStyle(GoosieTheme.charcoalOutline.opacity(0.6))

                                TextField("e.g., Drink 8 glasses of water", text: $title)
                                    .font(GoosieTheme.bodyFont())
                                    .textFieldStyle(.plain)
                            }
                        }

                        // Category picker
                        GoosieCard {
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Category")
                                    .font(GoosieTheme.captionFont())
                                    .foregroundStyle(GoosieTheme.charcoalOutline.opacity(0.6))

                                LazyVGrid(columns: [
                                    GridItem(.flexible()),
                                    GridItem(.flexible()),
                                    GridItem(.flexible()),
                                    GridItem(.flexible())
                                ], spacing: 10) {
                                    ForEach(GoalCategory.allCases, id: \.self) { cat in
                                        categoryChip(cat)
                                    }
                                }
                            }
                        }

                        // Frequency
                        GoosieCard {
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Frequency")
                                    .font(GoosieTheme.captionFont())
                                    .foregroundStyle(GoosieTheme.charcoalOutline.opacity(0.6))

                                HStack(spacing: 8) {
                                    ForEach(GoalFrequency.allCases, id: \.self) { freq in
                                        frequencyChip(freq)
                                    }
                                }
                            }
                        }

                        // Target count
                        GoosieCard {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Daily Target")
                                    .font(GoosieTheme.captionFont())
                                    .foregroundStyle(GoosieTheme.charcoalOutline.opacity(0.6))

                                Stepper(value: $targetCount, in: 1...99) {
                                    Text("\(targetCount) time\(targetCount > 1 ? "s" : "")")
                                        .font(GoosieTheme.bodyFont())
                                        .foregroundStyle(GoosieTheme.charcoalOutline)
                                }
                            }
                        }
                    }
                    .padding(GoosieTheme.padding)
                }
            }
            .navigationTitle(isEditing ? "Edit Goal" : "New Goal")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .onAppear { loadExistingGoal() }
        }
    }

    private func categoryChip(_ cat: GoalCategory) -> some View {
        let isSelected = category == cat
        let chipColor = Color(hex: UInt(cat.color, radix: 16) ?? 0xFFD93D)

        return Button {
            category = cat
        } label: {
            VStack(spacing: 4) {
                Image(systemName: cat.icon)
                    .font(.system(size: 16))
                Text(cat.displayName)
                    .font(GoosieTheme.captionFont(10))
            }
            .foregroundStyle(isSelected ? .white : GoosieTheme.charcoalOutline)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isSelected ? chipColor : chipColor.opacity(0.15))
            )
        }
    }

    private func frequencyChip(_ freq: GoalFrequency) -> some View {
        let isSelected = frequency == freq

        return Button {
            frequency = freq
        } label: {
            Text(freq.displayName)
                .font(GoosieTheme.captionFont(12))
                .foregroundStyle(isSelected ? .white : GoosieTheme.charcoalOutline)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(
                    Capsule()
                        .fill(isSelected ? GoosieTheme.coralAccent : GoosieTheme.coralAccent.opacity(0.15))
                )
        }
    }

    private func loadExistingGoal() {
        guard let goal = existingGoal else { return }
        title = goal.title
        category = goal.goalCategory
        frequency = goal.goalFrequency
        targetCount = goal.targetCount
    }

    private func save() {
        let trimmedTitle = title.trimmingCharacters(in: .whitespaces)
        guard !trimmedTitle.isEmpty else { return }

        if let goal = existingGoal {
            goal.title = trimmedTitle
            goal.category = category.rawValue
            goal.frequency = frequency.rawValue
            goal.targetCount = targetCount
        } else {
            let goal = Goal(
                title: trimmedTitle,
                category: category,
                frequency: frequency,
                targetCount: targetCount
            )
            modelContext.insert(goal)
        }
        dismiss()
    }
}
