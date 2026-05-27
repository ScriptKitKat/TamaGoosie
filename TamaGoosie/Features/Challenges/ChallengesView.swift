// TamaGoosie/Features/Challenges/ChallengesView.swift
import SwiftUI
import SwiftData

struct ChallengesView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \ChallengeTemplate.sortHint) private var templates: [ChallengeTemplate]
    @Query private var runs: [ChallengeRun]
    @Query private var gooseStates: [GooseState]
    @Query private var logs: [DailyLog]
    @State private var viewModel = ChallengeViewModel()
    @State private var detailTarget: ChallengeTemplate?
    @State private var completionTarget: ChallengeRun?
    @State private var showCapToast = false

    private var state: GooseState? { gooseStates.first }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                ChallengeHeader(
                    coins: state?.coins ?? 0,
                    activeCount: viewModel.activeCount(runs),
                    cap: GoosieConstants.challengeActiveCap
                )

                let active = viewModel.active(from: runs)
                if !active.isEmpty {
                    ChallengeListSection(.active, runs: active) { run in
                        ActiveChallengeCard(
                            run: run,
                            template: template(for: run),
                            progressFraction: viewModel.progressFraction(for: run, logs: logs),
                            currentProgress: viewModel.currentProgress(for: run, logs: logs)
                        ) {
                            viewModel.abandon(run, context: modelContext)
                        }
                    }
                }

                ChallengeListSection(.browse, templates: viewModel.browseable(from: templates, runs: runs)) { template in
                    let cooldown = viewModel.isInCooldown(template, runs: runs)
                    let cooldownEnds = viewModel.cooldownEnds(for: template, runs: runs)
                    let cap = !viewModel.canAccept(runs)
                    BrowseChallengeCard(
                        template: template,
                        inCooldown: cooldown,
                        cooldownEnds: cooldownEnds,
                        capReached: cap
                    ) {
                        if cooldown { return }
                        if cap {
                            withAnimation { showCapToast = true }
                            return
                        }
                        detailTarget = template
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 52)
            .padding(.bottom, 32)
        }
        .background(GrassyBackgroundView().ignoresSafeArea())
        .refreshable {
            await ChallengeSyncService.shared.pullAll(into: modelContext)
            if let state {
                let completed = ChallengeEngine.recomputeActive(state: state, logs: logs, runs: runs)
                viewModel.enqueueCompletions(completed)
            }
        }
        .onAppear {
            Task {
                await ChallengeSyncService.shared.pullAll(into: modelContext)
                if let state {
                    let completed = ChallengeEngine.recomputeActive(state: state, logs: logs, runs: runs)
                    viewModel.enqueueCompletions(completed)
                }
            }
        }
        .onChange(of: viewModel.pendingCompletions.count) { _, _ in
            if completionTarget == nil, let next = viewModel.popNextCompletion() {
                completionTarget = next
            }
        }
        .sheet(item: $detailTarget) { template in
            ChallengeDetailSheet(template: template) { tier in
                viewModel.accept(
                    template: template, tier: tier,
                    runs: runs, logs: logs, state: state,
                    context: modelContext
                )
                detailTarget = nil
            }
        }
        .sheet(item: $completionTarget) { run in
            ChallengeCompletionSheet(run: run, template: template(for: run)) {
                completionTarget = viewModel.popNextCompletion()
            }
        }
        .overlay(alignment: .bottom) {
            if showCapToast {
                Text("Finish one to start another")
                    .font(.callout).foregroundStyle(.white)
                    .padding(.horizontal, 16).padding(.vertical, 10)
                    .background(.black.opacity(0.7), in: Capsule())
                    .padding(.bottom, 80)
                    .task {
                        try? await Task.sleep(for: .seconds(2))
                        withAnimation { showCapToast = false }
                    }
            }
        }
    }

    private func template(for run: ChallengeRun) -> ChallengeTemplate? {
        templates.first { $0.templateId == run.templateId }
    }
}

private struct ChallengeHeader: View {
    let coins: Int
    let activeCount: Int
    let cap: Int
    var body: some View {
        HStack {
            Text("Challenges")
                .font(GoosieTheme.titleFont(22))
                .foregroundStyle(.white)
            Spacer()
            Text("Coins \(coins)")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.white)
                .padding(.horizontal, 12).padding(.vertical, 6)
                .background(.white.opacity(0.2), in: Capsule())
        }
    }
}
