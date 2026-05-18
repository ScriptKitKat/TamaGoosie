import SwiftUI

struct DayOfWeekPicker: View {
    @Binding var activeDays: Set<Int>

    private let dayLabels = ["S", "M", "T", "W", "T", "F", "S"]

    private let accentGreen = Color(hex: 0x4A8F4A)

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Days of week active")
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundStyle(GoosieTheme.charcoalOutline.opacity(0.6))
                Spacer()
                if activeDays.count == 7 {
                    Text("Every day")
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundStyle(GoosieTheme.charcoalOutline.opacity(0.4))
                }
            }

            HStack(spacing: 8) {
                ForEach(1...7, id: \.self) { day in
                    let isActive = activeDays.contains(day)
                    Button {
                        if isActive {
                            activeDays.remove(day)
                        } else {
                            activeDays.insert(day)
                        }
                    } label: {
                        Text(dayLabels[day - 1])
                            .font(.system(size: 14, weight: .bold, design: .rounded))
                            .foregroundStyle(isActive ? .white : GoosieTheme.charcoalOutline.opacity(0.4))
                            .frame(width: 38, height: 38)
                            .background(
                                Circle()
                                    .fill(isActive ? accentGreen : GoosieTheme.charcoalOutline.opacity(0.08))
                            )
                    }
                }
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white)
                .shadow(color: .black.opacity(0.06), radius: 4, y: 2)
        )
    }
}
