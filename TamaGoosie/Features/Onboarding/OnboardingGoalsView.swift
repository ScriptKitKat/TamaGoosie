import SwiftUI

struct OnboardingGoalsView: View {
    let obState: OnboardingState
    let onAdvance: () -> Void

    private let goals: [(title: String, category: GoalCategory)] = [
        ("Drink 8 glasses of water", .water),
        ("Take a 30-minute walk",    .fitness),
        ("Meditate for 10 minutes",  .mindfulness),
        ("Read for 20 minutes",      .learning),
        ("Stretch for 10 minutes",   .fitness),
        ("Journal before bed",       .mindfulness),
        ("Eat a healthy meal",       .health),
        ("Call a friend or family",  .social),
    ]

    private let columns = [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)]

    var body: some View {
        ZStack {
            OBTheme.cream.ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer().frame(height: 28)

                // Header
                Text("Pick 3 starter goals")
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundStyle(OBTheme.text)

                Text("Your goose grows happier when you hit them!")
                    .font(.system(size: 14, weight: .regular, design: .rounded))
                    .foregroundStyle(OBTheme.secondary)
                    .padding(.top, 6)

                // Counter
                Text("\(obState.selectedGoals.count)/3 selected")
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(obState.selectedGoals.count == 3 ? OBTheme.teal : OBTheme.secondary)
                    .padding(.top, 12)
                    .animation(.easeInOut(duration: 0.2), value: obState.selectedGoals.count)

                Spacer().frame(height: 16)

                // Goal grid
                LazyVGrid(columns: columns, spacing: 12) {
                    ForEach(goals, id: \.title) { goal in
                        GoalCard(
                            title: goal.title,
                            category: goal.category,
                            isSelected: obState.selectedGoals.contains(goal.title)
                        ) {
                            toggleGoal(goal.title)
                        }
                    }
                }
                .padding(.horizontal, 20)

                Spacer()

                OBButton(
                    title: "Continue",
                    isEnabled: obState.selectedGoals.count >= 1,
                    action: onAdvance
                )
                .padding(.bottom, 36)
            }
        }
    }

    private func toggleGoal(_ title: String) {
        if obState.selectedGoals.contains(title) {
            obState.selectedGoals.remove(title)
        } else if obState.selectedGoals.count < 3 {
            obState.selectedGoals.insert(title)
        }
    }
}

// MARK: - Goal Card

private struct GoalCard: View {
    let title: String
    let category: GoalCategory
    let isSelected: Bool
    let action: () -> Void

    private var accentColor: Color {
        Color(hex: UInt(category.color, radix: 16) ?? 0xA09080)
    }

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: category.icon)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(isSelected ? .white : accentColor)

                    Spacer()

                    if isSelected {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 16))
                            .foregroundStyle(.white)
                            .transition(.scale.combined(with: .opacity))
                    }
                }

                Text(title)
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundStyle(isSelected ? .white : OBTheme.text)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(isSelected ? accentColor : OBTheme.card)
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(isSelected ? accentColor : OBTheme.border, lineWidth: isSelected ? 2 : 1.5)
                    )
                    .shadow(color: OBTheme.border.opacity(0.4), radius: 4, y: 2)
            )
        }
        .buttonStyle(.plain)
        .animation(.spring(response: 0.28, dampingFraction: 0.7), value: isSelected)
    }
}
