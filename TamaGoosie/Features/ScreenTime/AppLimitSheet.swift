import SwiftUI
import SwiftData
import FamilyControls

struct AppLimitSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    var existingBlock: ScreenBlock?

    @State private var name: String = ""
    @State private var timeLimitMinutes: Int = 30
    @State private var activeDays: Set<Int> = Set(1...7)
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
                            Image(systemName: "hourglass")
                                .foregroundStyle(GoosieTheme.warmOrange)
                            TextField("Limit name", text: $name)
                                .font(.system(size: 18, weight: .bold, design: .rounded))
                                .foregroundStyle(GoosieTheme.charcoalOutline)
                        }
                        .padding(14)
                        .background(
                            RoundedRectangle(cornerRadius: 16).fill(cardBackground)
                                .shadow(color: .black.opacity(0.06), radius: 4, y: 2)
                        )

                        // App selection
                        Button { showPicker = true } label: {
                            HStack {
                                Text("App")
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

                        // Time allowed
                        VStack(spacing: 0) {
                            HStack {
                                Text("Time Allowed")
                                    .font(.system(size: 15, weight: .medium, design: .rounded))
                                    .foregroundStyle(GoosieTheme.charcoalOutline)
                                Spacer()
                                Stepper("\(timeLimitMinutes)m", value: $timeLimitMinutes, in: 15...240, step: 15)
                                    .font(.system(size: 15, weight: .bold, design: .rounded))
                                    .foregroundStyle(GoosieTheme.charcoalOutline)
                            }
                        }
                        .padding(14)
                        .background(
                            RoundedRectangle(cornerRadius: 16).fill(cardBackground)
                                .shadow(color: .black.opacity(0.06), radius: 4, y: 2)
                        )

                        // Days
                        DayOfWeekPicker(activeDays: $activeDays)

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
        timeLimitMinutes = block.timeLimitMinutes
        activeDays = block.activeDaysSet
        if let sel = block.selection { draftSelection = sel }
        selectionData = block.selectionData
    }

    private func save() {
        let block = existingBlock ?? ScreenBlock(name: name, type: "appLimit", selectionData: selectionData)

        block.name = name
        block.selectionData = selectionData
        block.timeLimitMinutes = timeLimitMinutes
        block.activeDaysSet = activeDays

        if existingBlock == nil {
            modelContext.insert(block)
        }
        try? modelContext.save()
        ScreenTimeManager.shared.registerBlock(block)
        dismiss()
    }
}
