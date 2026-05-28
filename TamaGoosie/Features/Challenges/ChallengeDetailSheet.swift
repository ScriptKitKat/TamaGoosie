// TamaGoosie/Features/Challenges/ChallengeDetailSheet.swift
import SwiftUI

struct ChallengeDetailSheet: View {
    let template: ChallengeTemplate
    let onStart: (ChallengeTier) -> Void
    @State private var tier: ChallengeTier = .silver
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 16) {
            Text(template.title).font(.title2.weight(.bold))
            Text(template.blurb)
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Text(howItWorks)
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Picker("Tier", selection: $tier) {
                ForEach(ChallengeTier.allCases, id: \.self) {
                    Text($0.rawValue.capitalized).tag($0)
                }
            }
            .pickerStyle(.segmented)

            HStack {
                Text("Target")
                Spacer()
                Text("\(Int(template.target(for: tier))) \(template.metric)")
                    .font(.body.weight(.semibold))
            }
            HStack {
                Text("Reward")
                Spacer()
                Text("\(template.reward(for: tier)) coins")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(GoosieTheme.warmOrange)
            }

            Button {
                onStart(tier)
                dismiss()
            } label: {
                Text("Start")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
            }
            .buttonStyle(.borderedProminent)
            .tint(GoosieTheme.hygieneGreen)
        }
        .padding(20)
        .presentationDetents([.medium])
    }

    private var howItWorks: String {
        let shape = ChallengeShape(rawValue: template.shape) ?? .cumulative
        switch shape {
        case .cumulative:
            return "Accumulate \(Int(template.target(for: tier))) \(template.metric) within \(template.windowDays) days."
        case .dailyCeiling:
            return "Stay under \(Int(template.target(for: tier))) \(template.metric) every day for \(template.windowDays) days."
        }
    }
}
