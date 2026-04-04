import SwiftUI
import SwiftData

struct DistractionConfigView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \DistractionApp.displayName) private var apps: [DistractionApp]

    @State private var showAddSheet = false
    @State private var newName = ""
    @State private var newLimit = 30

    var body: some View {
        ZStack {
            GoosieTheme.mintBackground.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 16) {
                    infoCard

                    if apps.isEmpty {
                        emptyState
                    } else {
                        ForEach(apps, id: \.id) { app in
                            appRow(app)
                        }
                    }

                    PillButton(title: "Add App", icon: "plus", color: GoosieTheme.coralAccent) {
                        showAddSheet = true
                    }
                    .padding(.top, 8)
                }
                .padding(GoosieTheme.padding)
            }
        }
        .navigationTitle("Distraction Apps")
        .navigationBarTitleDisplayMode(.large)
        .sheet(isPresented: $showAddSheet) {
            addAppSheet
        }
    }

    // MARK: - Subviews

    private var infoCard: some View {
        GoosieCard {
            HStack(spacing: 12) {
                Image(systemName: "iphone.slash")
                    .font(.system(size: 24))
                    .foregroundStyle(GoosieTheme.coralAccent)
                VStack(alignment: .leading, spacing: 4) {
                    Text("Track Distractions")
                        .font(GoosieTheme.bodyFont(15))
                        .foregroundStyle(GoosieTheme.charcoalOutline)
                    Text("Opening these apps decreases your goose's happiness.")
                        .font(GoosieTheme.captionFont(12))
                        .foregroundStyle(GoosieTheme.charcoalOutline.opacity(0.6))
                }
            }
        }
    }

    private var emptyState: some View {
        GoosieCard {
            VStack(spacing: 8) {
                Image(systemName: "app.badge.checkmark")
                    .font(.system(size: 36))
                    .foregroundStyle(GoosieTheme.charcoalOutline.opacity(0.3))
                Text("No distraction apps added yet")
                    .font(GoosieTheme.captionFont())
                    .foregroundStyle(GoosieTheme.charcoalOutline.opacity(0.5))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
        }
    }

    private func appRow(_ app: DistractionApp) -> some View {
        GoosieCard {
            HStack {
                Image(systemName: "app.fill")
                    .font(.system(size: 20))
                    .foregroundStyle(GoosieTheme.coralAccent)
                    .frame(width: 36, height: 36)
                    .background(GoosieTheme.coralAccent.opacity(0.15), in: RoundedRectangle(cornerRadius: 8))

                VStack(alignment: .leading, spacing: 3) {
                    Text(app.displayName)
                        .font(GoosieTheme.bodyFont(15))
                        .foregroundStyle(GoosieTheme.charcoalOutline)
                    Text("Limit: \(app.dailyLimitMinutes) min/day")
                        .font(GoosieTheme.captionFont(12))
                        .foregroundStyle(GoosieTheme.charcoalOutline.opacity(0.5))
                }

                Spacer()

                Button {
                    modelContext.delete(app)
                } label: {
                    Image(systemName: "trash")
                        .foregroundStyle(GoosieTheme.coralAccent)
                }
            }
        }
    }

    private var addAppSheet: some View {
        NavigationStack {
            Form {
                Section("App Name") {
                    TextField("e.g. Instagram, TikTok", text: $newName)
                        .autocorrectionDisabled()
                }
                Section("Daily Limit") {
                    Stepper("\(newLimit) minutes", value: $newLimit, in: 5...240, step: 5)
                }
            }
            .navigationTitle("Add Distraction App")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        resetSheet()
                        showAddSheet = false
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        guard !newName.trimmingCharacters(in: .whitespaces).isEmpty else { return }
                        let bundleID = newName.lowercased().replacingOccurrences(of: " ", with: ".")
                        let app = DistractionApp(bundleID: bundleID, displayName: newName, dailyLimitMinutes: newLimit)
                        modelContext.insert(app)
                        resetSheet()
                        showAddSheet = false
                    }
                    .fontWeight(.semibold)
                    .disabled(newName.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
        .presentationDetents([.medium])
    }

    private func resetSheet() {
        newName = ""
        newLimit = 30
    }
}
