// TamaGoosie/Features/Challenges/ChallengeCompletionSheet.swift
import SwiftUI

struct ChallengeCompletionSheet: View {
    let run: ChallengeRun
    let template: ChallengeTemplate?
    let onDismiss: () -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 18) {
            Text("Challenge Complete!").font(.title2.weight(.bold))
            Text(template?.title ?? run.templateId).font(.headline)
            TierChip(tier: run.tierEnum)

            // Reuse the existing coin animation. CoinAnimationView takes `amount:`.
            CoinAnimationView(amount: run.coinsAwarded ?? 0)
                .frame(height: 100)

            Text("\(run.coinsAwarded ?? 0) coins")
                .font(.title3.weight(.bold))
                .foregroundStyle(GoosieTheme.warmOrange)

            Button {
                dismiss()
                onDismiss()
            } label: {
                Text("Nice!")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
            }
            .buttonStyle(.borderedProminent)
            .tint(GoosieTheme.hygieneGreen)
        }
        .padding(24)
        .presentationDetents([.medium])
    }
}
