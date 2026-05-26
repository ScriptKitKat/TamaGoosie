import SwiftUI

struct BlockCardView: View {
    let block: ScreenBlock
    var onTap: () -> Void
    var onDelete: () -> Void

    private var manager: ScreenTimeManager { ScreenTimeManager.shared }

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
        return GoosieTheme.charcoalOutline.opacity(0.4)
    }

    var body: some View {
        VStack(spacing: 0) {
            // Main card content (tap to edit)
            Button(action: onTap) {
                HStack(spacing: 12) {
                    Image(systemName: typeIcon)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 36, height: 36)
                        .background(typeColor, in: RoundedRectangle(cornerRadius: 10))

                    VStack(alignment: .leading, spacing: 4) {
                        Text(block.name)
                            .font(.system(size: 15, weight: .bold, design: .rounded))
                            .foregroundStyle(GoosieTheme.charcoalOutline)

                        Text(block.scheduleSummary)
                            .font(.system(size: 12, weight: .medium, design: .rounded))
                            .foregroundStyle(GoosieTheme.charcoalOutline.opacity(0.5))

                        if block.type != "lock" {
                            Text(block.statusLabel)
                                .font(.system(size: 11, weight: .semibold, design: .rounded))
                                .foregroundStyle(statusColor)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(statusColor.opacity(0.15), in: Capsule())
                        }
                    }

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(GoosieTheme.charcoalOutline.opacity(0.3))
                }
            }
            .buttonStyle(.plain)

            // Lock controls
            if block.type == "lock" {
                Divider()
                    .padding(.vertical, 6)
                lockControls
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(.white)
                .shadow(color: .black.opacity(0.04), radius: 4, y: 2)
        )
        .contextMenu {
            Button(role: .destructive) {
                onDelete()
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
    }

    // MARK: - Lock Controls

    @ViewBuilder
    private var lockControls: some View {
        let isUnlocked = manager.isBlockUnlocked(block)
        let remaining = manager.lockOpensRemaining(block)

        if isUnlocked {
            TimelineView(.periodic(from: .now, by: 1)) { context in
                if let expiry = manager.lockUnlockExpiryDate(block) {
                    let seconds = max(0, Int(expiry.timeIntervalSince(context.date)))
                    HStack {
                        HStack(spacing: 4) {
                            Image(systemName: "lock.open.fill")
                                .font(.system(size: 11))
                            Text("\(seconds / 60):\(String(format: "%02d", seconds % 60)) left")
                                .font(.system(size: 13, weight: .bold, design: .rounded))
                                .monospacedDigit()
                        }
                        .foregroundStyle(.green)

                        Spacer()

                        Button {
                            manager.relockBlock(block)
                        } label: {
                            Text("Lock Now")
                                .font(.system(size: 12, weight: .bold, design: .rounded))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(.purple, in: Capsule())
                        }
                        .buttonStyle(.borderless)
                    }
                } else {
                    Text("Relocking...")
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundStyle(.secondary)
                }
            }
        } else if remaining > 0 {
            HStack {
                Text("\(remaining) unlock\(remaining == 1 ? "" : "s") left today")
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(GoosieTheme.charcoalOutline.opacity(0.5))

                Spacer()

                Button {
                    manager.unlockBlock(block)
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "lock.open.fill")
                            .font(.system(size: 11))
                        Text("Unlock")
                            .font(.system(size: 12, weight: .bold, design: .rounded))
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(.purple, in: Capsule())
                }
                .buttonStyle(.borderless)
            }
        } else {
            HStack {
                Image(systemName: "lock.fill")
                    .font(.system(size: 11))
                Text("No unlocks remaining today")
                    .font(.system(size: 12, weight: .medium, design: .rounded))
            }
            .foregroundStyle(.red.opacity(0.7))
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
                .foregroundStyle(GoosieTheme.charcoalOutline.opacity(0.4))
                .frame(width: 28, height: 28)
                .background(GoosieTheme.charcoalOutline.opacity(0.06), in: RoundedRectangle(cornerRadius: 8))

            VStack(alignment: .leading, spacing: 2) {
                Text(block.name)
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundStyle(GoosieTheme.charcoalOutline.opacity(0.6))

                if let completed = block.completedAt ?? block.endedAt {
                    Text(completed.formatted(date: .abbreviated, time: .shortened))
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundStyle(GoosieTheme.charcoalOutline.opacity(0.35))
                }
            }

            Spacer()

            if block.type == "blockNow" {
                Text("\(block.durationMinutes)m")
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(GoosieTheme.charcoalOutline.opacity(0.4))
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(.white)
                .shadow(color: .black.opacity(0.03), radius: 3, y: 1)
        )
    }
}
