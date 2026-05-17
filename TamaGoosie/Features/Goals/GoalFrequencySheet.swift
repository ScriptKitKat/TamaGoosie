import SwiftUI

struct GoalFrequencySheet: View {
    @Binding var frequency: GoalFrequency
    @Binding var customDays: Set<Int>
    @Environment(\.dismiss) private var dismiss

    private let weekdayLabels = ["Su", "Mo", "Tu", "We", "Th", "Fr", "Sa"]

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 20) {
                ForEach(GoalFrequency.allCases, id: \.self) { freq in
                    frequencyRow(freq)
                }

                if frequency == .custom {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Select days")
                            .font(GoosieTheme.captionFont(11))
                            .foregroundStyle(GoosieTheme.charcoalOutline.opacity(0.5))

                        HStack(spacing: 6) {
                            ForEach(0..<7, id: \.self) { index in
                                let weekday = index + 1
                                let isSelected = customDays.contains(weekday)
                                Button {
                                    if isSelected {
                                        customDays.remove(weekday)
                                    } else {
                                        customDays.insert(weekday)
                                    }
                                } label: {
                                    Text(weekdayLabels[index])
                                        .font(GoosieTheme.captionFont(12))
                                        .foregroundStyle(isSelected ? .white : GoosieTheme.charcoalOutline)
                                        .frame(width: 36, height: 36)
                                        .background(
                                            Circle()
                                                .fill(isSelected ? Color(hex: 0x43A047) : Color(hex: 0x43A047).opacity(0.12))
                                        )
                                }
                            }
                        }
                    }
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }

                Spacer()
            }
            .padding(GoosieTheme.padding)
            .animation(.easeInOut(duration: 0.2), value: frequency)
            .background(GoosieTheme.mintBackground.ignoresSafeArea())
            .navigationTitle("Frequency")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .preferredColorScheme(.light)
        }
        .presentationDetents([.medium])
    }

    private func frequencyRow(_ freq: GoalFrequency) -> some View {
        let isSelected = frequency == freq
        return Button {
            frequency = freq
        } label: {
            HStack {
                Text(freq.displayName)
                    .font(GoosieTheme.bodyFont())
                    .foregroundStyle(GoosieTheme.charcoalOutline)
                Spacer()
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(Color(hex: 0x43A047))
                }
            }
            .padding(.vertical, 8)
        }
    }
}
