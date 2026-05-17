import SwiftUI

struct BlockCardView: View {
    let block: ScreenBlock
    var onTap: () -> Void
    var onDelete: () -> Void

    private var typeIcon: String {
        switch block.type {
        case "blockNow": return "timer"
        case "schedule": return "calendar.badge.clock"
        case "appLimit": return "hourglass"
        case "lock": return "lock.fill"
        default: return "questionmark.circle"
        }
    }

    private var typeColor: Color {
        switch block.type {
        case "blockNow": return GoosieTheme.coralAccent
        case "schedule": return GoosieTheme.skyBlue
        case "appLimit": return GoosieTheme.warmOrange
        case "lock": return .purple
        default: return .gray
        }
    }

    private var statusColor: Color {
        let label = block.statusLabel
        if label.contains("Active") { return .green }
        if label.contains("Disabled") || label.contains("Off") { return .gray }
        if label.contains("Starting") { return GoosieTheme.skyBlue }
        return .white.opacity(0.5)
    }

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                Image(systemName: typeIcon)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 36, height: 36)
                    .background(typeColor.opacity(0.85), in: RoundedRectangle(cornerRadius: 10))

                VStack(alignment: .leading, spacing: 4) {
                    Text(block.name)
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)

                    Text(block.scheduleSummary)
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundStyle(.white.opacity(0.5))

                    Text(block.statusLabel)
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                        .foregroundStyle(statusColor)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(statusColor.opacity(0.15), in: Capsule())
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.3))
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(.white.opacity(0.08))
            )
        }
        .contextMenu {
            Button(role: .destructive) {
                onDelete()
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
    }
}

// MARK: - Past Block Row (compact, for history section)

struct PastBlockRow: View {
    let block: ScreenBlock

    private var typeIcon: String {
        switch block.type {
        case "blockNow": return "timer"
        case "schedule": return "calendar.badge.clock"
        case "appLimit": return "hourglass"
        case "lock": return "lock.fill"
        default: return "questionmark.circle"
        }
    }

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: typeIcon)
                .font(.system(size: 14))
                .foregroundStyle(.white.opacity(0.4))
                .frame(width: 28, height: 28)
                .background(.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 8))

            VStack(alignment: .leading, spacing: 2) {
                Text(block.name)
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.6))

                if let completed = block.completedAt ?? block.endedAt {
                    Text(completed.formatted(date: .abbreviated, time: .shortened))
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundStyle(.white.opacity(0.35))
                }
            }

            Spacer()

            if block.type == "blockNow" {
                Text("\(block.durationMinutes)m")
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.4))
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(.white.opacity(0.05))
        )
    }
}
