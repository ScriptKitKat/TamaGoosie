import SwiftUI
import SwiftData

struct ScreenTimeBlocksTab: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \ScreenBlock.createdAt, order: .reverse) private var allBlocks: [ScreenBlock]

    @State private var showBlockNow = false
    @State private var showSchedule = false
    @State private var showAppLimit = false
    @State private var showLock = false
    @State private var editingBlock: ScreenBlock?
    @State private var showHistory = false

    private var activeBlocks: [ScreenBlock] {
        allBlocks.filter { !$0.isPast }
    }

    private var pastBlocks: [ScreenBlock] {
        allBlocks.filter { $0.isPast }
            .sorted { ($0.completedAt ?? $0.endedAt ?? .distantPast) > ($1.completedAt ?? $1.endedAt ?? .distantPast) }
    }

    var body: some View {
        VStack(spacing: 16) {
            if activeBlocks.isEmpty && pastBlocks.isEmpty {
                emptyState
            } else {
                // Active blocks
                if !activeBlocks.isEmpty {
                    VStack(spacing: 10) {
                        ForEach(activeBlocks, id: \.id) { block in
                            BlockCardView(
                                block: block,
                                onTap: { editBlock(block) },
                                onDelete: { deleteBlock(block) }
                            )
                        }
                    }
                }

                // Past section
                if !pastBlocks.isEmpty {
                    pastSection
                }
            }

            // New block buttons
            newBlockSection

            Spacer().frame(height: 20)
        }
        .fullScreenCover(isPresented: $showBlockNow) {
            BlockNowSheet(existingBlock: editingBlock?.type == "blockNow" ? editingBlock : nil)
        }
        .fullScreenCover(isPresented: $showSchedule) {
            ScheduleSessionSheet(existingBlock: editingBlock?.type == "schedule" ? editingBlock : nil)
        }
        .fullScreenCover(isPresented: $showAppLimit) {
            AppLimitSheet(existingBlock: editingBlock?.type == "appLimit" ? editingBlock : nil)
        }
        .fullScreenCover(isPresented: $showLock) {
            LockSheet(existingBlock: editingBlock?.type == "lock" ? editingBlock : nil)
        }
        .onChange(of: showBlockNow) { _, showing in if !showing { editingBlock = nil } }
        .onChange(of: showSchedule) { _, showing in if !showing { editingBlock = nil } }
        .onChange(of: showAppLimit) { _, showing in if !showing { editingBlock = nil } }
        .onChange(of: showLock) { _, showing in if !showing { editingBlock = nil } }
    }

    // MARK: - New Block Section

    private var newBlockSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("New Block")
                .font(.system(size: 13, weight: .heavy, design: .rounded))
                .foregroundStyle(GoosieTheme.charcoalOutline.opacity(0.5))

            HStack(spacing: 12) {
                newBlockButton(icon: "timer", label: "Block Now", color: GoosieTheme.coralAccent) {
                    editingBlock = nil
                    showBlockNow = true
                }
                newBlockButton(icon: "calendar.badge.clock", label: "Schedule", color: GoosieTheme.skyBlue) {
                    editingBlock = nil
                    showSchedule = true
                }
                newBlockButton(icon: "hourglass", label: "App Limit", color: GoosieTheme.warmOrange) {
                    editingBlock = nil
                    showAppLimit = true
                }
                newBlockButton(icon: "lock.fill", label: "Lock", color: .purple) {
                    editingBlock = nil
                    showLock = true
                }
            }
        }
    }

    private func newBlockButton(icon: String, label: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 20, weight: .medium))
                    .foregroundStyle(color)
                    .frame(width: 48, height: 48)
                    .background(color.opacity(0.12), in: RoundedRectangle(cornerRadius: 12))

                Text(label)
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundStyle(GoosieTheme.charcoalOutline.opacity(0.6))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .frame(maxWidth: .infinity)
        }
    }

    // MARK: - Past Section

    private var pastSection: some View {
        VStack(spacing: 0) {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    showHistory.toggle()
                }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: showHistory ? "chevron.down" : "chevron.right")
                        .font(.system(size: 11, weight: .bold))
                    Text("Past")
                        .font(.system(size: 13, weight: .heavy, design: .rounded))
                    Text("\(pastBlocks.count)")
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundStyle(GoosieTheme.charcoalOutline.opacity(0.35))
                    Spacer()
                }
                .foregroundStyle(GoosieTheme.charcoalOutline.opacity(0.5))
                .padding(.vertical, 8)
            }

            if showHistory {
                VStack(spacing: 8) {
                    ForEach(pastBlocks, id: \.id) { block in
                        PastBlockRow(block: block)
                    }
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "shield.checkered")
                .font(.system(size: 40))
                .foregroundStyle(GoosieTheme.charcoalOutline.opacity(0.2))

            Text("No blocks set up")
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundStyle(GoosieTheme.charcoalOutline)

            Text("Here are some ideas to get you started")
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundStyle(GoosieTheme.charcoalOutline.opacity(0.4))

            Button {
                editingBlock = nil
                showBlockNow = true
            } label: {
                HStack {
                    Image(systemName: "play.fill")
                        .font(.system(size: 14))
                    Text("Block Now")
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(
                    GoosieTheme.coralAccent,
                    in: RoundedRectangle(cornerRadius: 14)
                )
            }
            .padding(.top, 8)
        }
        .padding(.top, 40)
    }

    // MARK: - Helpers

    private func editBlock(_ block: ScreenBlock) {
        editingBlock = block
        switch block.type {
        case "blockNow": showBlockNow = true
        case "schedule": showSchedule = true
        case "appLimit": showAppLimit = true
        case "lock": showLock = true
        default: break
        }
    }

    private func deleteBlock(_ block: ScreenBlock) {
        ScreenTimeManager.shared.unregisterBlock(block)
        modelContext.delete(block)
        try? modelContext.save()
    }
}
