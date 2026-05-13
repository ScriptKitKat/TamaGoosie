import SwiftUI
import SwiftData

struct StatsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var profiles: [UserProfile]
    @Query private var gooseStates: [GooseState]

    @State private var selectedDetail: StatDetailType? = nil

    private var profile: UserProfile? { profiles.first }

    private var gooseName: String { gooseStates.first?.name ?? "Harold" }

    private var provider: DailyLogHistoryProvider {
        DailyLogHistoryProvider(modelContext: modelContext)
    }

    private var hasEnoughData: Bool {
        provider.fetchPoints(range: .week).count >= 2
    }

    private var gooseState: GooseState? { gooseStates.first }

    var body: some View {
        ZStack {
            Color(hex: 0xF5F5F0)
                .ignoresSafeArea()

            if hasEnoughData {
                ScrollView {
                    VStack(spacing: 0) {
                        // Goose summary header
                        gooseHeader
                            .padding(.horizontal, GoosieTheme.padding)

                        // Chart card
                        DuckHistoryCard()
                            .padding(.horizontal, GoosieTheme.padding)
                            .padding(.top, 16)

                        // Average stats row
                        if let state = gooseState {
                            averageStatsRow(state: state)
                                .padding(.horizontal, GoosieTheme.padding)
                                .padding(.top, 12)
                        }

                        // Details section
                        detailsSection
                            .padding(.top, 24)
                    }
                    .padding(.top, 52)
                    .padding(.bottom, 20)
                }
            } else {
                emptyStateView
            }
        }
        .sheet(item: $selectedDetail) { detail in
            StatDetailSheet(detailType: detail)
        }
    }

    // MARK: - Goose Header

    private var gooseHeader: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(Color(hex: 0xC5E1A5).opacity(0.4))
                    .frame(width: 56, height: 56)

                GooseCharacterView(mood: gooseState.map { GooseMood.deriveMood(healthiness: $0.healthiness, happiness: $0.happiness) } ?? .content)
                    .frame(width: 44, height: 44)
                    .clipShape(Circle())

                if let state = gooseState {
                    Text("\(Int((state.healthiness + state.happiness) / 2.0 * 100))")
                        .font(.system(size: 9, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .frame(width: 22, height: 22)
                        .background(Circle().fill(Color(hex: 0x42A5F5)))
                        .offset(x: -16, y: 16)
                }
            }

            VStack(alignment: .leading, spacing: 2) {
                Text("\(gooseName)'s Stats")
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundStyle(GoosieTheme.charcoalOutline.opacity(0.5))
                Text("Overview")
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundStyle(GoosieTheme.charcoalOutline)
            }

            Spacer()
        }
        .padding(.top, 8)
    }

    // MARK: - Average Stats Row

    private func averageStatsRow(state: GooseState) -> some View {
        HStack(spacing: 12) {
            HStack {
                Text("Avg Health")
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundStyle(GoosieTheme.charcoalOutline.opacity(0.5))
                Spacer()
                Text("\(Int(state.healthiness * 100))")
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundStyle(GoosieTheme.charcoalOutline)
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(.white)
                    .shadow(color: .black.opacity(0.04), radius: 2, y: 1)
            )

            HStack {
                Text("Avg Happiness")
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundStyle(GoosieTheme.charcoalOutline.opacity(0.5))
                Spacer()
                Text("\(Int(state.happiness * 100))")
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundStyle(GoosieTheme.charcoalOutline)
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(.white)
                    .shadow(color: .black.opacity(0.04), radius: 2, y: 1)
            )
        }
    }

    // MARK: - Details Section

    private var detailsSection: some View {
        VStack(spacing: 0) {
            // Section header with green accent bar
            HStack(spacing: 0) {
                RoundedRectangle(cornerRadius: 2)
                    .fill(Color(hex: 0x43A047))
                    .frame(width: 4, height: 20)
                    .padding(.trailing, 10)

                Text("Details")
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)

                Spacer()
            }
            .padding(.horizontal, GoosieTheme.padding)
            .padding(.vertical, 10)
            .background(
                LinearGradient(
                    colors: [Color(hex: 0x66BB6A), Color(hex: 0x43A047)],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )

            // Feature grid
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
                detailTile(type: .healthTrends)
                detailTile(type: .happinessTrends)
                detailTile(type: .activityLog)
                detailTile(type: .sleepData)
                detailTile(type: .bestDays)
                detailTile(type: .baselines)
            }
            .padding(.horizontal, GoosieTheme.padding)
            .padding(.top, 16)
        }
    }

    private func detailTile(type: StatDetailType) -> some View {
        Button {
            selectedDetail = type
        } label: {
            HStack(spacing: 10) {
                Image(systemName: type.icon)
                    .font(.system(size: 20))
                    .foregroundStyle(type.accentColor)
                    .frame(width: 32)

                Text(type.rawValue)
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(GoosieTheme.charcoalOutline.opacity(0.8))
                    .multilineTextAlignment(.leading)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(.white)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .strokeBorder(type.accentColor.opacity(0.25), lineWidth: 1.5)
                    )
                    .shadow(color: .black.opacity(0.03), radius: 2, y: 1)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Empty State

    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "chart.line.uptrend.xyaxis")
                .font(.system(size: 48))
                .foregroundStyle(GoosieTheme.charcoalOutline.opacity(0.2))
            Text("\(gooseName) needs a few more days to show you trends")
                .font(.system(size: 15, weight: .medium, design: .rounded))
                .foregroundStyle(GoosieTheme.charcoalOutline.opacity(0.5))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.top, 52)
    }
}
