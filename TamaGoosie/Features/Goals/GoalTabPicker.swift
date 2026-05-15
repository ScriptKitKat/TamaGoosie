import SwiftUI

enum GoalTab: String, CaseIterable {
    case today = "Today"
    case habits = "Habits"
    case quests = "Quests"
}

struct GoalTabPicker: View {
    @Binding var selected: GoalTab

    private let pokGreen = Color(hex: 0x43A047)

    var body: some View {
        HStack(spacing: 0) {
            ForEach(GoalTab.allCases, id: \.self) { tab in
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        selected = tab
                    }
                } label: {
                    Text(tab.rawValue)
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundStyle(selected == tab ? .white : GoosieTheme.charcoalOutline.opacity(0.6))
                        .padding(.horizontal, 20)
                        .padding(.vertical, 8)
                        .background(
                            Capsule()
                                .fill(selected == tab ? pokGreen : .clear)
                        )
                }
            }
        }
        .padding(4)
        .background(
            Capsule()
                .fill(Color.white)
                .shadow(color: .black.opacity(0.06), radius: 2, y: 1)
        )
    }
}
