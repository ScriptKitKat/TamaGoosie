import SwiftUI
import SwiftData
import FamilyControls

struct BlockNowSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    var existingBlock: ScreenBlock?

    @State private var name: String = "Focus Session"
    @State private var durationMinutes: Int = 25
    @State private var showPicker = false
    @State private var draftSelection = FamilyActivitySelection()
    @State private var selectionData: Data?

    // Active session state
    @State private var activeBlock: ScreenBlock?
    @State private var timer: Timer?
    @State private var remainingSeconds: Int = 0

    private var hasSelection: Bool {
        !draftSelection.applicationTokens.isEmpty || !draftSelection.categoryTokens.isEmpty
    }

    private var isSessionActive: Bool {
        activeBlock?.startedAt != nil && activeBlock?.endedAt == nil
    }

    private let accentGreen = Color(hex: 0x4A8F4A)
    private let sheetBackground = Color(hex: 0xF5F5F0)
    private let cardBackground = Color.white

    var body: some View {
        NavigationStack {
            ZStack {
                if isSessionActive {
                    LinearGradient(
                        colors: [Color(hex: 0x6BAE6B), Color(hex: 0x95D095)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .ignoresSafeArea()
                } else {
                    sheetBackground.ignoresSafeArea()
                }

                ScrollView {
                    VStack(spacing: 16) {
                        if isSessionActive {
                            activeSessionView
                        } else {
                            configView
                        }
                    }
                    .padding(GoosieTheme.padding)
                    .padding(.top, 20)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        if isSessionActive {
                            endSession()
                        }
                        dismiss()
                    } label: {
                        Image(systemName: "chevron.down")
                            .foregroundStyle(isSessionActive ? .white.opacity(0.6) : GoosieTheme.charcoalOutline.opacity(0.5))
                    }
                }
            }
            .familyActivityPicker(isPresented: $showPicker, selection: $draftSelection)
            .onChange(of: showPicker) { wasShowing, isShowing in
                if wasShowing && !isShowing {
                    selectionData = try? PropertyListEncoder().encode(draftSelection)
                }
            }
            .onAppear {
                if let block = existingBlock {
                    name = block.name
                    durationMinutes = block.durationMinutes
                    if let sel = block.selection {
                        draftSelection = sel
                    }
                    selectionData = block.selectionData
                    if block.startedAt != nil && block.endedAt == nil {
                        activeBlock = block
                        remainingSeconds = block.blockNowRemainingSeconds
                        startTimer()
                    }
                }
            }
            .onDisappear {
                timer?.invalidate()
            }
            .preferredColorScheme(isSessionActive ? .dark : .light)
        }
    }

    // MARK: - Config View

    private var configView: some View {
        VStack(spacing: 16) {
            // Name
            HStack {
                Image(systemName: "flame.fill")
                    .foregroundStyle(.orange)
                TextField("Session name", text: $name)
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundStyle(GoosieTheme.charcoalOutline)
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(cardBackground)
                    .shadow(color: .black.opacity(0.06), radius: 4, y: 2)
            )

            // Duration
            HStack {
                Text("Duration")
                    .font(.system(size: 15, weight: .medium, design: .rounded))
                    .foregroundStyle(GoosieTheme.charcoalOutline)
                Spacer()
                Stepper("\(durationMinutes)m", value: $durationMinutes, in: 5...120, step: 5)
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundStyle(GoosieTheme.charcoalOutline)
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(cardBackground)
                    .shadow(color: .black.opacity(0.06), radius: 4, y: 2)
            )

            // Apps Blocked
            Button { showPicker = true } label: {
                HStack {
                    Text("Apps Blocked")
                        .font(.system(size: 15, weight: .medium, design: .rounded))
                        .foregroundStyle(GoosieTheme.charcoalOutline)
                    Spacer()
                    let count = draftSelection.applicationTokens.count + draftSelection.categoryTokens.count
                    Text(count > 0 ? "\(count) selected" : "Choose")
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .foregroundStyle(GoosieTheme.charcoalOutline.opacity(0.45))
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(GoosieTheme.charcoalOutline.opacity(0.3))
                }
                .padding(14)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(cardBackground)
                        .shadow(color: .black.opacity(0.06), radius: 4, y: 2)
                )
            }

            Spacer().frame(height: 20)

            // Start button
            Button(action: startSession) {
                Text("Start Session")
                    .font(.system(size: 17, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(accentGreen, in: RoundedRectangle(cornerRadius: 16))
                    .shadow(color: accentGreen.opacity(0.4), radius: 8, y: 4)
            }
            .disabled(!hasSelection)
            .opacity(hasSelection ? 1 : 0.4)
        }
    }

    // MARK: - Active Session View

    private var activeSessionView: some View {
        VStack(spacing: 24) {
            Spacer().frame(height: 20)

            // Timer ring
            ZStack {
                Circle()
                    .stroke(.white.opacity(0.2), lineWidth: 8)
                    .frame(width: 220, height: 220)

                Circle()
                    .trim(from: 0, to: sessionProgress)
                    .stroke(
                        .white,
                        style: StrokeStyle(lineWidth: 8, lineCap: .round)
                    )
                    .frame(width: 220, height: 220)
                    .rotationEffect(.degrees(-90))
                    .animation(.linear(duration: 1), value: sessionProgress)

                VStack(spacing: 4) {
                    Text(displayTime)
                        .font(.system(size: 44, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .contentTransition(.numericText())

                    Text(name)
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .foregroundStyle(.white.opacity(0.5))
                }
            }

            Spacer()

            // End session button
            Button(action: endSession) {
                Text("End Session")
                    .font(.system(size: 17, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(accentGreen.opacity(0.8), in: RoundedRectangle(cornerRadius: 16))
                    .shadow(color: .black.opacity(0.15), radius: 6, y: 3)
            }
        }
    }

    private var sessionProgress: Double {
        let total = Double(durationMinutes * 60)
        guard total > 0 else { return 0 }
        return 1.0 - (Double(remainingSeconds) / total)
    }

    private var displayTime: String {
        let mins = remainingSeconds / 60
        let secs = remainingSeconds % 60
        return String(format: "%02d:%02d", mins, secs)
    }

    // MARK: - Session Management

    private func startSession() {
        let block = ScreenBlock(name: name, type: "blockNow", selectionData: selectionData)
        block.durationMinutes = durationMinutes
        block.startSession()
        modelContext.insert(block)
        try? modelContext.save()

        activeBlock = block
        remainingSeconds = durationMinutes * 60

        ScreenTimeManager.shared.registerBlock(block)
        startTimer()
    }

    private func endSession() {
        timer?.invalidate()
        timer = nil
        if let block = activeBlock {
            block.endSession()
            ScreenTimeManager.shared.unregisterBlock(block)
            try? modelContext.save()
        }
        dismiss()
    }

    private func startTimer() {
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
            if remainingSeconds > 0 {
                remainingSeconds -= 1
            } else {
                endSession()
            }
        }
    }
}
