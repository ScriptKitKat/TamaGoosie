import SwiftUI

struct GooseGlanceView: View {
    @State private var syncService = WatchSyncReceiver.shared
    @State private var showQuickLog = false

    private var payload: GooseSyncPayload {
        syncService.currentPayload
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
                        .trim(from: 0, to: payload.healthiness)
                        .stroke(
                            healthColor,
                            style: StrokeStyle(lineWidth: 6, lineCap: .round)
                        )
                        .frame(width: 100, height: 100)
                        .rotationEffect(.degrees(-90))

                    Text(payload.moodEnum.emoji)
                        .font(.system(size: 36))
                }

                // Name
                Text(payload.name)
                    .font(.system(size: 16, weight: .bold, design: .rounded))

                // Mini stat bars (2 stats)
                VStack(spacing: 4) {
                    watchStatBar("Health", value: payload.healthiness, color: .red)
                    watchStatBar("Happy", value: payload.happiness, color: .yellow)
                }
                .padding(.horizontal)

                // Streak
                if payload.streakDays > 0 {
                    HStack(spacing: 4) {
                        Image(systemName: "flame.fill")
                            .foregroundStyle(.orange)
                            .font(.system(size: 12))
                        Text("\(payload.streakDays) day streak")
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
        if payload.healthiness > 0.6 { return .green }
        if payload.healthiness > 0.3 { return .yellow }
        return .red
    }

    /// Display a stat bar for 0.0–1.0 values
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
                        .frame(width: max(0, geo.size.width * value))
                }
            }
            .frame(height: 6)
        }
    }
}
