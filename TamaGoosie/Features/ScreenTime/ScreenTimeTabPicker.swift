import SwiftUI

enum ScreenTimeTab: String, CaseIterable {
    case stats = "Stats"
    case blocks = "Blocks"
}

enum ScreenTimePeriod: String, CaseIterable {
    case today = "Today"
    case yesterday = "Yesterday"
    case week = "This Week"
}

struct ScreenTimeTabPicker: View {
    @Binding var selected: ScreenTimeTab
    @Binding var period: ScreenTimePeriod

    private let selectedGreen = Color(hex: 0x4A8F4A)

    var body: some View {
        HStack(spacing: 12) {
            // "Today" dropdown
            Menu {
                ForEach(ScreenTimePeriod.allCases, id: \.self) { p in
                    Button {
                        period = p
                    } label: {
                        if p == period {
                            Label(p.rawValue, systemImage: "checkmark")
                        } else {
                            Text(p.rawValue)
                        }
                    }
                }
            } label: {
                HStack(spacing: 4) {
                    Text(period.rawValue)
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                    Image(systemName: "chevron.down")
                        .font(.system(size: 11, weight: .bold))
                }
                .foregroundStyle(GoosieTheme.charcoalOutline)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(
                    Capsule()
                        .fill(.white)
                        .shadow(color: .black.opacity(0.06), radius: 2, y: 1)
                )
            }

            Spacer()

            // Stats / Blocks toggle
            HStack(spacing: 0) {
                ForEach(ScreenTimeTab.allCases, id: \.self) { tab in
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            selected = tab
                        }
                    } label: {
                        Text(tab.rawValue)
                            .font(.system(size: 13, weight: .bold, design: .rounded))
                            .foregroundStyle(selected == tab ? .white : GoosieTheme.charcoalOutline.opacity(0.5))
                            .padding(.horizontal, 16)
                            .padding(.vertical, 7)
                            .background(
                                Capsule()
                                    .fill(selected == tab ? selectedGreen : .clear)
                            )
                    }
                }
            }
            .padding(3)
            .background(
                Capsule()
                    .fill(.white.opacity(0.7))
                    .shadow(color: .black.opacity(0.06), radius: 2, y: 1)
            )
        }
    }
}
