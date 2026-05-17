import SwiftUI

enum ScreenTimeTab: String, CaseIterable {
    case stats = "Stats"
    case blocks = "Blocks"
}

struct ScreenTimeTabPicker: View {
    @Binding var selected: ScreenTimeTab

    var body: some View {
        HStack(spacing: 0) {
            ForEach(ScreenTimeTab.allCases, id: \.self) { tab in
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        selected = tab
                    }
                } label: {
                    Text(tab.rawValue)
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundStyle(selected == tab ? .white : GoosieTheme.charcoalOutline.opacity(0.6))
                        .padding(.horizontal, 24)
                        .padding(.vertical, 8)
                        .background(
                            Capsule()
                                .fill(selected == tab ? GoosieTheme.skyBlue : .clear)
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
