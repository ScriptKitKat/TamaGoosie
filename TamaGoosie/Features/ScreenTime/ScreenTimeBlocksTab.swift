import SwiftUI
import SwiftData

struct ScreenTimeBlocksTab: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \ScreenBlock.createdAt, order: .reverse) private var allBlocks: [ScreenBlock]
    @State private var manager = ScreenTimeManager.shared

    @State private var showBlockNow = false
    @State private var showSchedule = false
    @State private var showAppLimit = false
    @State private var showLock = false
    @State private var editingBlock: ScreenBlock?
    @State private var showHistory = false
    @State private var showDiagnostics = false

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

            // Debug diagnostics (temporary)
            diagnosticsSection

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
                .foregroundStyle(.white.opacity(0.7))

            HStack(spacing: 12) {
                newBlockButton(icon: "timer", label: "Block Now", color: Color(hex: 0xE87461)) {
                    editingBlock = nil
                    showBlockNow = true
                }
                newBlockButton(icon: "calendar.badge.clock", label: "Schedule", color: Color(hex: 0x5BA3D9)) {
                    editingBlock = nil
                    showSchedule = true
                }
                newBlockButton(icon: "hourglass", label: "App Limit", color: Color(hex: 0xFFB74D)) {
                    editingBlock = nil
                    showAppLimit = true
                }
                newBlockButton(icon: "lock.fill", label: "Lock", color: Color(hex: 0x7E57C2)) {
                    editingBlock = nil
                    showLock = true
                }
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 18)
                    .fill(.white)
                    .shadow(color: .black.opacity(0.06), radius: 6, y: 3)
            )
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
                        .foregroundStyle(.white.opacity(0.5))
                    Spacer()
                }
                .foregroundStyle(.white.opacity(0.7))
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
                .foregroundStyle(.white.opacity(0.4))

            Text("No blocks set up")
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundStyle(.white)

            Text("Here are some ideas to get you started")
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundStyle(.white.opacity(0.6))

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
                    Color(hex: 0x4A8F4A),
                    in: RoundedRectangle(cornerRadius: 14)
                )
                .shadow(color: .black.opacity(0.1), radius: 6, y: 3)
            }
            .padding(.top, 8)
        }
        .padding(.top, 40)
    }

    // MARK: - Diagnostics

    private var diagnosticsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    showDiagnostics.toggle()
                }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: showDiagnostics ? "chevron.down" : "chevron.right")
                        .font(.system(size: 11, weight: .bold))
                    Text("Debug Info")
                        .font(.system(size: 13, weight: .heavy, design: .rounded))
                    Spacer()
                }
                .foregroundStyle(.white.opacity(0.5))
                .padding(.vertical, 4)
            }

            if showDiagnostics {
                VStack(alignment: .leading, spacing: 8) {
                    Group {
                        Text("Registered Activities:")
                            .font(.system(size: 11, weight: .bold, design: .monospaced))
                        let activities = manager.registeredActivities
                        if activities.isEmpty {
                            Text("  (none)")
                                .font(.system(size: 10, design: .monospaced))
                        } else {
                            ForEach(activities, id: \.self) { a in
                                Text("  \(a)")
                                    .font(.system(size: 10, design: .monospaced))
                            }
                        }
                    }

                    Divider().background(.white.opacity(0.3))

                    Group {
                        if let last = manager.extensionLastCallback {
                            Text("Extension last fired: \(last.formatted(date: .abbreviated, time: .standard))")
                                .font(.system(size: 10, design: .monospaced))
                        } else {
                            Text("Extension has NEVER fired")
                                .font(.system(size: 10, weight: .bold, design: .monospaced))
                                .foregroundStyle(.red)
                        }
                        Text("Bundle: \(manager.extensionBundleStatus)")
                            .font(.system(size: 10, design: .monospaced))
                    }

                    Divider().background(.white.opacity(0.3))

                    Group {
                        Text("Extension Log:")
                            .font(.system(size: 11, weight: .bold, design: .monospaced))
                        let extLog = manager.extensionBreadcrumbs
                        if extLog.isEmpty {
                            Text("  (empty — extension never called)")
                                .font(.system(size: 10, design: .monospaced))
                        } else {
                            ForEach(Array(extLog.suffix(10).enumerated()), id: \.offset) { _, entry in
                                Text(entry)
                                    .font(.system(size: 9, design: .monospaced))
                                    .lineLimit(3)
                            }
                        }
                    }

                    Divider().background(.white.opacity(0.3))

                    Group {
                        Text("Manager Log:")
                            .font(.system(size: 11, weight: .bold, design: .monospaced))
                        let mgrLog = manager.managerBreadcrumbs
                        if mgrLog.isEmpty {
                            Text("  (empty)")
                                .font(.system(size: 10, design: .monospaced))
                        } else {
                            ForEach(Array(mgrLog.suffix(10).enumerated()), id: \.offset) { _, entry in
                                Text(entry)
                                    .font(.system(size: 9, design: .monospaced))
                                    .lineLimit(3)
                            }
                        }
                    }

                    Button("Clear Diagnostics") {
                        manager.clearDiagnostics()
                    }
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .padding(.vertical, 8)
                    .padding(.horizontal, 16)
                    .background(.red.opacity(0.5), in: Capsule())
                }
                .foregroundStyle(.white.opacity(0.8))
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: 14)
                        .fill(.black.opacity(0.3))
                )
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
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
