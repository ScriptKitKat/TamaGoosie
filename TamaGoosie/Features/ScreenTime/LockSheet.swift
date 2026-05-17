import SwiftUI
import SwiftData
import FamilyControls

struct LockSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    var existingBlock: ScreenBlock?

    @State private var name: String = ""
    @State private var opensAllowed: Int = 3
    @State private var unlockDurationMinutes: Int = 5
    @State private var activeDays: Set<Int> = Set(1...7)
    @State private var showPicker = false
    @State private var draftSelection = FamilyActivitySelection()
    @State private var selectionData: Data?

    private var hasSelection: Bool {
        !draftSelection.applicationTokens.isEmpty || !draftSelection.categoryTokens.isEmpty
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 16) {
                        // Name
                        HStack {
                            Image(systemName: "lock.fill")
                                .foregroundStyle(.purple)
                            TextField("Lock name", text: $name)
                                .font(.system(size: 18, weight: .bold, design: .rounded))
                                .foregroundStyle(.white)
                        }
                        .padding(14)
                        .background(RoundedRectangle(cornerRadius: 14).fill(.white.opacity(0.08)))

                        // App selection
                        Button { showPicker = true } label: {
                            HStack {
                                Text("Apps Blocked")
                                    .font(.system(size: 15, weight: .medium, design: .rounded))
                                    .foregroundStyle(.white)
                                Spacer()
                                let count = draftSelection.applicationTokens.count + draftSelection.categoryTokens.count
                                Text(count > 0 ? "\(count) selected" : "Choose")
                                    .font(.system(size: 14, weight: .medium, design: .rounded))
                                    .foregroundStyle(.white.opacity(0.5))
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundStyle(.white.opacity(0.3))
                            }
                            .padding(14)
                            .background(RoundedRectangle(cornerRadius: 14).fill(.white.opacity(0.08)))
                        }

                        // Explanation
                        Text("The app is **blocked at all times** but you can unlock it a set number of times per day.")
                            .font(.system(size: 13, weight: .medium, design: .rounded))
                            .foregroundStyle(.white.opacity(0.6))
                            .padding(.horizontal, 4)

                        // Lock settings
                        VStack(spacing: 0) {
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Opens Allowed")
                                        .font(.system(size: 15, weight: .medium, design: .rounded))
                                        .foregroundStyle(.white)
                                    Text("Per day")
                                        .font(.system(size: 11, weight: .medium, design: .rounded))
                                        .foregroundStyle(.white.opacity(0.4))
                                }
                                Spacer()
                                Stepper("\(opensAllowed)", value: $opensAllowed, in: 1...20)
                                    .font(.system(size: 15, weight: .bold, design: .rounded))
                                    .foregroundStyle(.white)
                            }
                            .padding(.vertical, 10)

                            Divider().background(.white.opacity(0.1))

                            HStack {
                                Text("For Up To")
                                    .font(.system(size: 15, weight: .medium, design: .rounded))
                                    .foregroundStyle(.white)
                                Spacer()
                                Stepper("\(unlockDurationMinutes)m", value: $unlockDurationMinutes, in: 5...60, step: 5)
                                    .font(.system(size: 15, weight: .bold, design: .rounded))
                                    .foregroundStyle(.white)
                            }
                            .padding(.vertical, 10)
                        }
                        .padding(.horizontal, 14)
                        .background(RoundedRectangle(cornerRadius: 14).fill(.white.opacity(0.08)))

                        // Days
                        DayOfWeekPicker(activeDays: $activeDays)

                        Spacer().frame(height: 20)

                        // Save
                        Button(action: save) {
                            Text("Save")
                                .font(.system(size: 17, weight: .bold, design: .rounded))
                                .foregroundStyle(.black)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .background(.white, in: RoundedRectangle(cornerRadius: 16))
                        }
                        .disabled(name.isEmpty || !hasSelection)
                        .opacity(name.isEmpty || !hasSelection ? 0.4 : 1)

                        // Remove button (edit mode only)
                        if existingBlock != nil {
                            Button(role: .destructive) {
                                if let block = existingBlock {
                                    ScreenTimeManager.shared.unregisterBlock(block)
                                    modelContext.delete(block)
                                    try? modelContext.save()
                                }
                                dismiss()
                            } label: {
                                Text("Remove Lock")
                                    .font(.system(size: 15, weight: .bold, design: .rounded))
                                    .foregroundStyle(.red)
                            }
                        }
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
                            .foregroundStyle(.white.opacity(0.6))
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
            .preferredColorScheme(.dark)
        }
    }

    private func loadExisting() {
        guard let block = existingBlock else { return }
        name = block.name
        opensAllowed = block.opensAllowed
        unlockDurationMinutes = block.unlockDurationMinutes
        activeDays = block.activeDaysSet
        if let sel = block.selection { draftSelection = sel }
        selectionData = block.selectionData
    }

    private func save() {
        let block = existingBlock ?? ScreenBlock(name: name, type: "lock", selectionData: selectionData)

        block.name = name
        block.selectionData = selectionData
        block.opensAllowed = opensAllowed
        block.unlockDurationMinutes = unlockDurationMinutes
        block.activeDaysSet = activeDays

        if existingBlock == nil {
            modelContext.insert(block)
        }
        try? modelContext.save()
        ScreenTimeManager.shared.registerBlock(block)
        dismiss()
    }
}
