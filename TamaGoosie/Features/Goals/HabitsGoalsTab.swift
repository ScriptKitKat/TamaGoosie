import SwiftUI
import SwiftData

struct HabitsGoalsTab: View {
    let habits: [Goal]
    let viewModel: GoalViewModel
    let modelContext: ModelContext

    private let pokGreen = Color(hex: 0x43A047)

    private var longestStreak: Int {
        habits.map(\.currentStreak).max() ?? 0
    }

    private var thisWeekPercent: Int {
        let cal = Calendar.current
        let today = cal.startOfDay(for: .now)
        let weekday = cal.component(.weekday, from: today)
        let daysFromMonday = (weekday + 5) % 7
        guard let monday = cal.date(byAdding: .day, value: -daysFromMonday, to: today) else { return 0 }

        let daysElapsed = daysFromMonday + 1
        let totalSlots = daysElapsed * max(habits.count, 1)

        var completedSlots = 0
        for habit in habits {
            for dayOffset in 0..<daysElapsed {
                if let date = cal.date(byAdding: .day, value: dayOffset, to: monday) {
                    if habit.completionDates.contains(where: { cal.isDate($0, inSameDayAs: date) }) {
                        completedSlots += 1
                    }
                }
            }
        }

        guard totalSlots > 0 else { return 0 }
        return Int(Double(completedSlots) / Double(totalSlots) * 100)
    }

    var body: some View {
        VStack(spacing: 0) {
            Text("\(habits.count) active \u{00B7} longest streak \(longestStreak) days")
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundStyle(.white.opacity(0.7))
                .padding(.bottom, 12)

            statsRow
                .padding(.horizontal, GoosieTheme.padding)
                .padding(.bottom, 16)

            if habits.isEmpty {
                emptyState
            } else {
                VStack(spacing: 10) {
                    ForEach(habits, id: \.id) { habit in
                        habitCard(for: habit)
                    }
                }
                .padding(.horizontal, GoosieTheme.padding)
            }

            newHabitButton
                .padding(.horizontal, GoosieTheme.padding)
                .padding(.top, 12)
        }
    }

    // MARK: - Stats Row

    private var statsRow: some View {
        HStack(spacing: 12) {
            statCard(value: "\(longestStreak)", label: "longest streak")
            statCard(value: "\(thisWeekPercent)%", label: "this week")
        }
    }

    private func statCard(value: String, label: String) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundStyle(pokGreen)

            Text(label)
                .font(.system(size: 11, weight: .medium, design: .rounded))
                .foregroundStyle(GoosieTheme.charcoalOutline.opacity(0.5))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(.white)
                .shadow(color: .black.opacity(0.06), radius: 2, y: 1)
        )
    }

    // MARK: - Habit Card

    private func habitCard(for habit: Goal) -> some View {
        let categoryColor = Color(hex: UInt(habit.colorHex, radix: 16) ?? 0xFFD93D)

        return VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 12) {
                Image(systemName: habit.icon)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 32, height: 32)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(categoryColor)
                    )

                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Text(habit.title)
                            .font(.system(size: 15, weight: .bold, design: .rounded))
                            .foregroundStyle(.black.opacity(0.75))

                        if habit.targetCount > 1 {
                            Text("\(habit.targetCount)x")
                                .font(.system(size: 10, weight: .heavy, design: .rounded))
                                .foregroundStyle(pokGreen)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(
                                    RoundedRectangle(cornerRadius: 4)
                                        .fill(pokGreen.opacity(0.12))
                                )
                        }
                    }

                    Text(habit.goalFrequency.displayName)
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundStyle(.black.opacity(0.4))
                }

                Spacer()

                if habit.currentStreak > 0 {
                    HStack(spacing: 2) {
                        Image(systemName: "flame.fill")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(Color(hex: 0xFF6D00))
                        Text("\(habit.currentStreak)")
                            .font(.system(size: 14, weight: .heavy, design: .rounded))
                            .foregroundStyle(.black.opacity(0.6))
                    }
                }

                Menu {
                    Button { viewModel.startEditing(habit) } label: {
                        Label("Edit", systemImage: "pencil")
                    }
                    if habit.type != "builtin" {
                        Button(role: .destructive) {
                            viewModel.deleteGoal(habit, in: modelContext)
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(.primary.opacity(0.3))
                        .frame(width: 24, height: 24)
                        .contentShape(Rectangle())
                }
            }

            WeeklyHeatMap(completionDates: habit.completionDates)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(.white)
                .shadow(color: .black.opacity(0.10), radius: 2, y: 1)
        )
    }

    // MARK: - Supporting Views

    private var newHabitButton: some View {
        Button {
            viewModel.startCreating()
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "plus")
                    .font(.system(size: 14, weight: .bold))
                Text("New habit")
                    .font(.system(size: 14, weight: .heavy, design: .rounded))
            }
            .foregroundStyle(pokGreen)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .strokeBorder(pokGreen.opacity(0.4), style: StrokeStyle(lineWidth: 1.5, dash: [6, 4]))
            )
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "repeat")
                .font(.system(size: 40))
                .foregroundStyle(.white.opacity(0.4))
            Text("No habits yet")
                .font(.system(size: 16, weight: .heavy, design: .rounded))
                .foregroundStyle(.white.opacity(0.7))
        }
        .padding(.top, 40)
    }
}
