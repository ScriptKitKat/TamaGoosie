import SwiftUI

struct GooseGlanceView: View {
    @State private var syncService = WatchSyncReceiver.shared
    @State private var showQuickLog = false

    private var stats: GooseStats {
        syncService.currentStats
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 8) {
                // Health ring with mood emoji
                ZStack {
                    Circle()
                        .stroke(Color.gray.opacity(0.2), lineWidth: 6)
                        .frame(width: 100, height: 100)

                    Circle()
                        .trim(from: 0, to: stats.health / 100)
                        .stroke(
                            healthColor,
                            style: StrokeStyle(lineWidth: 6, lineCap: .round)
                        )
                        .frame(width: 100, height: 100)
                        .rotationEffect(.degrees(-90))

                    Text(stats.mood.emoji)
                        .font(.system(size: 36))
                }

                // Name and level
                VStack(spacing: 2) {
                    Text(stats.gooseName)
                        .font(.system(size: 16, weight: .bold, design: .rounded))

                    Text("Lv.\(stats.level)")
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundStyle(.secondary)
                }

                // Mini stat bars
                VStack(spacing: 4) {
                    watchStatBar("Health", value: stats.health, color: .red)
                    watchStatBar("Happy", value: stats.happiness, color: .yellow)
                    watchStatBar("Energy", value: stats.energy, color: .blue)
                    watchStatBar("Hygiene", value: stats.hygiene, color: .green)
                }
                .padding(.horizontal)

                // Streak
                if stats.streakDays > 0 {
                    HStack(spacing: 4) {
                        Image(systemName: "flame.fill")
                            .foregroundStyle(.orange)
                            .font(.system(size: 12))
                        Text("\(stats.streakDays) day streak")
                            .font(.system(size: 12, design: .rounded))
                    }
                }
            }
            .navigationTitle("TamaGoosie")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .bottomBar) {
                    Button {
                        showQuickLog = true
                    } label: {
                        Label("Goals", systemImage: "checklist")
                    }
                }
            }
            .sheet(isPresented: $showQuickLog) {
                QuickLogView()
            }
        }
    }

    private var healthColor: Color {
        if stats.health > 60 { return .green }
        if stats.health > 30 { return .yellow }
        return .red
    }

    private func watchStatBar(_ label: String, value: Double, color: Color) -> some View {
        HStack(spacing: 6) {
            Text(label)
                .font(.system(size: 10))
                .frame(width: 44, alignment: .leading)

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(color.opacity(0.2))
                    Capsule()
                        .fill(color)
                        .frame(width: max(0, geo.size.width * (value / 100)))
                }
            }
            .frame(height: 6)
        }
    }
}
