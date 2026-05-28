// TamaGoosie/Features/Challenges/ChallengeCard.swift
import SwiftUI

/// Active run card — shows progress, days left, and reward-on-complete.
struct ActiveChallengeCard: View {
    let run: ChallengeRun
    let template: ChallengeTemplate?
    let progressFraction: Double  // 0...1, computed by ViewModel
    let currentProgress: Double   // raw aggregate (for dailyCeiling day count display)
    let onAbandon: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(template?.title ?? "Challenge")
                    .font(.subheadline.weight(.bold))
                Spacer()
                TierChip(tier: run.tierEnum)
            }
            Text(metaLine)
                .font(.caption).foregroundStyle(.secondary)
            if run.shapeEnum == .cumulative {
                ProgressView(value: progressFraction)
                    .tint(GoosieTheme.hygieneGreen)
            } else {
                Text(ceilingLine).font(.caption2).foregroundStyle(.secondary)
            }
            Text("Reward: \(run.rewardSnapshot) coins on complete")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(GoosieTheme.warmOrange)
        }
        .padding(12)
        .background(.white, in: RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(GoosieTheme.sunYellow, lineWidth: 2))
        .contextMenu {
            Button(role: .destructive) { onAbandon() } label: {
                Label("Abandon", systemImage: "xmark")
            }
        }
    }

    private var metaLine: String {
        let daysLeft = max(0, Calendar.current.dateComponents([.day], from: Date(), to: run.expiresAt).day ?? 0)
        if run.shapeEnum == .cumulative {
            return "\(Int(currentProgress)) / \(Int(run.targetSnapshot)) \(run.metricSnapshot) · \(daysLeft)d left"
        } else {
            return "\(Int(currentProgress))/\(run.windowDaysSnapshot) days · \(daysLeft)d left"
        }
    }

    private var ceilingLine: String {
        "Hold under \(Int(run.targetSnapshot)) for \(run.windowDaysSnapshot) days"
    }
}

/// Browse card — tappable, shows tier chips, dims in cooldown.
struct BrowseChallengeCard: View {
    let template: ChallengeTemplate
    let inCooldown: Bool
    let cooldownEnds: Date?
    let capReached: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 6) {
                Text(template.title).font(.subheadline.weight(.bold))
                Text(template.blurb)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                HStack(spacing: 6) {
                    TierChip(tier: .bronze)
                    TierChip(tier: .silver)
                    TierChip(tier: .gold)
                }
                if inCooldown, let ends = cooldownEnds {
                    Text("Available in \(daysUntil(ends))d")
                        .font(.caption2).foregroundStyle(.secondary)
                }
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.white, in: RoundedRectangle(cornerRadius: 14))
            .grayscale(inCooldown ? 0.8 : 0)
            .opacity(inCooldown ? 0.6 : 1)
        }
        .buttonStyle(.plain)
        .disabled(inCooldown)
    }

    private func daysUntil(_ date: Date) -> Int {
        max(0, Calendar.current.dateComponents([.day], from: Date(), to: date).day ?? 0)
    }
}

struct TierChip: View {
    let tier: ChallengeTier
    var body: some View {
        Text(tier.rawValue.capitalized)
            .font(.caption2.weight(.semibold))
            .padding(.horizontal, 8).padding(.vertical, 3)
            .background(color.opacity(0.2), in: Capsule())
            .foregroundStyle(color)
    }

    private var color: Color {
        switch tier {
        case .bronze: return .brown
        case .silver: return .gray
        case .gold:   return .orange
        }
    }
}
