import SwiftUI
import SwiftData
import FamilyControls

struct ScheduleSessionSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    var existingBlock: ScreenBlock?

    @State private var name: String = ""
    @State private var startTime = Calendar.current.date(from: DateComponents(hour: 8, minute: 0)) ?? Date()
    @State private var endTime = Calendar.current.date(from: DateComponents(hour: 9, minute: 0)) ?? Date()
    @State private var activeDays: Set<Int> = Set(1...7)
    @State private var isVacationMode = false
    @State private var showPicker = false
    @State private var draftSelection = FamilyActivitySelection()
    @State private var selectionData: Data?

    private let accentGreen = Color(hex: 0x4A8F4A)
    private let sheetBackground = Color(hex: 0xF5F5F0)
    private let cardBackground = Color.white

    private var hasSelection: Bool {
        !draftSelection.applicationTokens.isEmpty || !draftSelection.categoryTokens.isEmpty
    }

    var body: some View {
        NavigationStack {
            ZStack {
                sheetBackground.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 16) {
                        // Name
                        HStack {
                            Image(systemName: "calendar.badge.clock")
                                .foregroundStyle(GoosieTheme.skyBlue)
                            TextField("Session name", text: $name)
                                .font(.system(size: 18, weight: .bold, design: .rounded))
                                .foregroundStyle(GoosieTheme.charcoalOutline)
                        }
                        .padding(14)
                        .background(
                            RoundedRectangle(cornerRadius: 16).fill(cardBackground)
                                .shadow(color: .black.opacity(0.06), radius: 4, y: 2)
                        )

                        // Time range
                        VStack(spacing: 0) {
                            HStack {
                                Circle().fill(accentGreen).frame(width: 8, height: 8)
                                Text("From")
                                    .font(.system(size: 15, weight: .medium, design: .rounded))
                                    .foregroundStyle(GoosieTheme.charcoalOutline)
                                Spacer()
                                DatePicker("", selection: $startTime, displayedComponents: .hourAndMinute)
                                    .labelsHidden()
                            }
                            .padding(.vertical, 10)

                            Divider()

                            HStack {
                                Circle().stroke(GoosieTheme.charcoalOutline.opacity(0.3), lineWidth: 1.5).frame(width: 8, height: 8)
                                Text("To")
                                    .font(.system(size: 15, weight: .medium, design: .rounded))
                                    .foregroundStyle(GoosieTheme.charcoalOutline)
                                Spacer()
                                DatePicker("", selection: $endTime, displayedComponents: .hourAndMinute)
                                    .labelsHidden()
                            }
                            .padding(.vertical, 10)
                        }
                        .padding(.horizontal, 14)
                        .background(
                            RoundedRectangle(cornerRadius: 16).fill(cardBackground)
                                .shadow(color: .black.opacity(0.06), radius: 4, y: 2)
                        )

                        // Days
                        DayOfWeekPicker(activeDays: $activeDays)

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
                                RoundedRectangle(cornerRadius: 16).fill(cardBackground)
                                    .shadow(color: .black.opacity(0.06), radius: 4, y: 2)
                            )
                        }

                        // Vacation mode
                        if existingBlock != nil {
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Vacation Mode")
                                        .font(.system(size: 15, weight: .medium, design: .rounded))
                                        .foregroundStyle(GoosieTheme.charcoalOutline)
                                    Text("Temporarily disable this session")
                                        .font(.system(size: 12, weight: .medium, design: .rounded))
                                        .foregroundStyle(GoosieTheme.charcoalOutline.opacity(0.45))
                                }
                                Spacer()
                                Toggle("", isOn: $isVacationMode)
                                    .labelsHidden()
                                    .tint(accentGreen)
                            }
                            .padding(14)
                            .background(
                                RoundedRectangle(cornerRadius: 16).fill(cardBackground)
                                    .shadow(color: .black.opacity(0.06), radius: 4, y: 2)
                            )
                        }

                        Spacer().frame(height: 20)

                        // Save
                        Button(action: save) {
                            Text("Save")
                                .font(.system(size: 17, weight: .bold, design: .rounded))
                                .foregroundStyle(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .background(accentGreen, in: RoundedRectangle(cornerRadius: 16))
                                .shadow(color: accentGreen.opacity(0.4), radius: 8, y: 4)
                        }
                        .disabled(name.isEmpty || !hasSelection)
                        .opacity(name.isEmpty || !hasSelection ? 0.4 : 1)
                    }
                    .padding(GoosieTheme.padding)
                    .padding(.top, 20)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button { dismiss() } label: {
                        Image(systemName: "chevron.down")
                            .foregroundStyle(GoosieTheme.charcoalOutline.opacity(0.5))
                    }
                }
            }
            .familyActivityPicker(isPresented: $showPicker, selection: $draftSelection)
            .onChange(of: showPicker) { wasShowing, isShowing in
                if wasShowing && !isShowing {
                    selectionData = try? PropertyListEncoder().encode(draftSelection)
                }
            }
            .onAppear { loadExisting() }
        }
    }

    private func loadExisting() {
        guard let block = existingBlock else { return }
        name = block.name
        activeDays = block.activeDaysSet
        isVacationMode = block.isVacationMode
        if let sel = block.selection { draftSelection = sel }
        selectionData = block.selectionData

        var startComps = DateComponents()
        startComps.hour = block.scheduleStartHour
        startComps.minute = block.scheduleStartMinute
        startTime = Calendar.current.date(from: startComps) ?? startTime

        var endComps = DateComponents()
        endComps.hour = block.scheduleEndHour
        endComps.minute = block.scheduleEndMinute
        endTime = Calendar.current.date(from: endComps) ?? endTime
    }

    private func save() {
        let block = existingBlock ?? ScreenBlock(name: name, type: "schedule", selectionData: selectionData)

        block.name = name
        block.selectionData = selectionData
        block.isVacationMode = isVacationMode
        block.activeDaysSet = activeDays

        let startComps = Calendar.current.dateComponents([.hour, .minute], from: startTime)
        block.scheduleStartHour = startComps.hour ?? 8
        block.scheduleStartMinute = startComps.minute ?? 0
        let endComps = Calendar.current.dateComponents([.hour, .minute], from: endTime)
        block.scheduleEndHour = endComps.hour ?? 22
        block.scheduleEndMinute = endComps.minute ?? 0

        if existingBlock == nil {
            modelContext.insert(block)
        }
        try? modelContext.save()

        if !block.isVacationMode {
            ScreenTimeManager.shared.registerBlock(block)
        } else {
            ScreenTimeManager.shared.unregisterBlock(block)
        }

        dismiss()
    }
}
