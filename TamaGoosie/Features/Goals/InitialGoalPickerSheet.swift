import SwiftUI
import SwiftData

struct InitialGoalPickerSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query private var profiles: [UserProfile]

    @State private var selectedGoals: Set<String> = []

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
        NavigationStack {
            ZStack {
                GoosieTheme.mintBackground.ignoresSafeArea()

                VStack(spacing: 0) {
                    Spacer().frame(height: 12)

                    Text("Pick up to 3 starter goals")
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .foregroundStyle(GoosieTheme.charcoalOutline)

                    Text("Your goose grows happier when you hit them!")
                        .font(.system(size: 14, weight: .regular, design: .rounded))
                        .foregroundStyle(GoosieTheme.charcoalOutline.opacity(0.6))
                        .padding(.top, 6)

                    Text("\(selectedGoals.count)/3 selected")
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundStyle(selectedGoals.count == 3 ? GoosieTheme.charcoalOutline : GoosieTheme.charcoalOutline.opacity(0.5))
                        .padding(.top, 12)

                    Spacer().frame(height: 16)

                    LazyVGrid(columns: columns, spacing: 12) {
                        ForEach(goals, id: \.title) { goal in
                            goalCard(title: goal.title, category: goal.category)
                        }
                    }
                    .padding(.horizontal, 20)

                    Spacer()

                    Button {
                        saveGoals()
                    } label: {
                        Text("Continue")
                            .font(.system(size: 17, weight: .semibold, design: .rounded))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(
                                RoundedRectangle(cornerRadius: 28)
                                    .fill(selectedGoals.count >= 1
                                          ? GoosieTheme.charcoalOutline
                                          : GoosieTheme.charcoalOutline.opacity(0.3))
                            )
                    }
                    .disabled(selectedGoals.isEmpty)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 36)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .interactiveDismissDisabled()
        }
    }

    private func goalCard(title: String, category: GoalCategory) -> some View {
        let isSelected = selectedGoals.contains(title)
        let accentColor = Color(hex: UInt(category.color, radix: 16) ?? 0xA09080)

        return Button {
            if isSelected {
                selectedGoals.remove(title)
            } else if selectedGoals.count < 3 {
                selectedGoals.insert(title)
            }
        } label: {
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
                    .foregroundStyle(isSelected ? .white : GoosieTheme.charcoalOutline)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(isSelected ? accentColor : GoosieTheme.creamWhite)
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(isSelected ? accentColor : GoosieTheme.charcoalOutline.opacity(0.15), lineWidth: isSelected ? 2 : 1.5)
                    )
                    .shadow(color: GoosieTheme.charcoalOutline.opacity(0.08), radius: 4, y: 2)
            )
        }
        .buttonStyle(.plain)
        .animation(.spring(response: 0.28, dampingFraction: 0.7), value: isSelected)
    }

    private func saveGoals() {
        guard let profile = profiles.first else { return }

        let goalDefs: [(String, GoalCategory)] = [
            ("Drink 8 glasses of water", .water),
            ("Take a 30-minute walk",    .fitness),
            ("Meditate for 10 minutes",  .mindfulness),
            ("Read for 20 minutes",      .learning),
            ("Stretch for 10 minutes",   .fitness),
            ("Journal before bed",       .mindfulness),
            ("Eat a healthy meal",       .health),
            ("Call a friend or family",  .social),
        ]

        var createdGoals: [Goal] = []
        for (idx, (title, category)) in goalDefs.enumerated() {
            guard selectedGoals.contains(title) else { continue }
            let goal = Goal(
                title: title,
                type: "recurring",
                category: category,
                frequency: .daily,
                happinessWeight: 1.0,
                sortOrder: idx
            )
            goal.userProfile = profile
            modelContext.insert(goal)
            profile.goals.append(goal)
            createdGoals.append(goal)
        }

        profile.hasPickedInitialGoals = true
        try? modelContext.save()

        ConvexManager.shared.syncGoals(goals: createdGoals)
        dismiss()
    }
}
