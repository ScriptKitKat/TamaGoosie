import SwiftUI
import SwiftData

struct OnboardingView: View {
    @Environment(\.modelContext) private var modelContext
    @Binding var hasCompletedOnboarding: Bool

    @State private var currentPage = 0
    @State private var gooseName = "Harnold"
    @State private var selectedGoals: Set<String> = []
    @State private var eggHatched = false

    private let presetGoals: [(String, GoalCategory)] = [
        ("Drink 8 glasses of water", .health),
        ("Take a 30-minute walk", .fitness),
        ("Meditate for 10 minutes", .mindfulness),
        ("Read for 20 minutes", .learning),
        ("Stretch for 10 minutes", .fitness),
        ("Journal before bed", .mindfulness),
        ("Eat a healthy meal", .health),
        ("Call a friend or family", .social),
        ("Practice a skill", .learning),
        ("Brush teeth 2x", .hygiene),
        ("Clean room/desk", .hygiene),
        ("Complete top 3 tasks", .productivity),
    ]

    var body: some View {
        ZStack {
            GoosieTheme.mintBackground
                .ignoresSafeArea()

            TabView(selection: $currentPage) {
                welcomePage.tag(0)
                namePage.tag(1)
                goalsPage.tag(2)
                healthPage.tag(3)
                notificationPage.tag(4)
            }
            .tabViewStyle(.page(indexDisplayMode: .always))
            .animation(.easeInOut, value: currentPage)
        }
    }

    // MARK: - Page 1: Welcome

    private var welcomePage: some View {
        VStack(spacing: 24) {
            Spacer()

            // Egg / hatching animation
            ZStack {
                if eggHatched {
                    GooseCharacterView(mood: .ecstatic, phase: .baby)
                        .transition(.scale.combined(with: .opacity))
                } else {
                    eggView
                        .onTapGesture {
                            withAnimation(.spring(response: 0.5, dampingFraction: 0.6)) {
                                eggHatched = true
                            }
                        }
                }
            }
            .frame(height: 220)

            Text("Welcome to TamaGoosie!")
                .font(GoosieTheme.titleFont(28))
                .foregroundStyle(GoosieTheme.charcoalOutline)

            Text(eggHatched ? "Your goose has hatched!" : "Tap the egg to hatch your goose!")
                .font(GoosieTheme.bodyFont())
                .foregroundStyle(GoosieTheme.charcoalOutline.opacity(0.6))

            Spacer()

            if eggHatched {
                nextButton { currentPage = 1 }
            }
        }
        .padding(GoosieTheme.padding)
    }

    private var eggView: some View {
        ZStack {
            Ellipse()
                .fill(GoosieTheme.creamWhite)
                .frame(width: 120, height: 150)
                .overlay(
                    Ellipse()
                        .stroke(GoosieTheme.charcoalOutline, lineWidth: 3)
                )
                .shadow(color: GoosieTheme.softPink.opacity(0.3), radius: 10, y: 5)

            // Crack lines
            Path { path in
                path.move(to: CGPoint(x: 40, y: 75))
                path.addLine(to: CGPoint(x: 55, y: 65))
                path.addLine(to: CGPoint(x: 65, y: 80))
                path.addLine(to: CGPoint(x: 80, y: 70))
            }
            .stroke(GoosieTheme.charcoalOutline.opacity(0.3), lineWidth: 1.5)
        }
    }

    // MARK: - Page 2: Name

    private var namePage: some View {
        VStack(spacing: 24) {
            Spacer()

            GooseCharacterView(mood: .happy, phase: .baby)
                .frame(height: 180)

            Text("Name your goose")
                .font(GoosieTheme.titleFont(24))
                .foregroundStyle(GoosieTheme.charcoalOutline)

            TextField("Goose name", text: $gooseName)
                .font(GoosieTheme.titleFont(22))
                .multilineTextAlignment(.center)
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: GoosieTheme.smallCornerRadius)
                        .fill(GoosieTheme.creamWhite)
                )
                .padding(.horizontal, 40)

            Spacer()
            nextButton { currentPage = 2 }
        }
        .padding(GoosieTheme.padding)
    }

    // MARK: - Page 3: Goals

    private var goalsPage: some View {
        VStack(spacing: 16) {
            Text("Pick 3 starter goals")
                .font(GoosieTheme.titleFont(24))
                .foregroundStyle(GoosieTheme.charcoalOutline)

            Text("You can always add more later!")
                .font(GoosieTheme.captionFont())
                .foregroundStyle(GoosieTheme.charcoalOutline.opacity(0.5))

            ScrollView {
                LazyVGrid(columns: [GridItem(.flexible())], spacing: 8) {
                    ForEach(presetGoals, id: \.0) { goal, category in
                        goalChip(goal, category: category)
                    }
                }
            }

            Spacer()

            Text("\(selectedGoals.count)/3 selected")
                .font(GoosieTheme.captionFont())
                .foregroundStyle(GoosieTheme.charcoalOutline.opacity(0.5))

            nextButton {
                currentPage = 3
            }
            .disabled(selectedGoals.isEmpty)
        }
        .padding(GoosieTheme.padding)
    }

    private func goalChip(_ title: String, category: GoalCategory) -> some View {
        let isSelected = selectedGoals.contains(title)
        let chipColor = Color(hex: UInt(category.color, radix: 16) ?? 0xFFD93D)

        return Button {
            if isSelected {
                selectedGoals.remove(title)
            } else if selectedGoals.count < 3 {
                selectedGoals.insert(title)
            }
        } label: {
            HStack {
                Image(systemName: category.icon)
                    .foregroundStyle(isSelected ? .white : chipColor)
                Text(title)
                    .font(GoosieTheme.bodyFont(14))
                    .foregroundStyle(isSelected ? .white : GoosieTheme.charcoalOutline)
                Spacer()
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.white)
                }
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isSelected ? chipColor : chipColor.opacity(0.1))
            )
        }
    }

    // MARK: - Page 4: HealthKit

    private var healthPage: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "heart.text.square.fill")
                .font(.system(size: 60))
                .foregroundStyle(GoosieTheme.coralAccent)

            Text("Connect Health Data?")
                .font(GoosieTheme.titleFont(24))
                .foregroundStyle(GoosieTheme.charcoalOutline)

            Text("Your goose gets healthier when you exercise, sleep well, and stay active.")
                .font(GoosieTheme.bodyFont())
                .foregroundStyle(GoosieTheme.charcoalOutline.opacity(0.6))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 20)

            Spacer()

            VStack(spacing: 12) {
                PillButton(title: "Connect Health", icon: "heart.fill", color: GoosieTheme.coralAccent) {
                    Task {
                        try? await HealthKitManager.shared.requestAuthorization()
                        currentPage = 4
                    }
                }

                Button("Skip for now") {
                    currentPage = 4
                }
                .font(GoosieTheme.captionFont())
                .foregroundStyle(GoosieTheme.charcoalOutline.opacity(0.5))
            }
        }
        .padding(GoosieTheme.padding)
    }

    // MARK: - Page 5: Notifications

    private var notificationPage: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "bell.badge.fill")
                .font(.system(size: 60))
                .foregroundStyle(GoosieTheme.sunYellow)

            Text("Stay in touch!")
                .font(GoosieTheme.titleFont(24))
                .foregroundStyle(GoosieTheme.charcoalOutline)

            Text("Get reminders to check on your goose and celebrate milestones.")
                .font(GoosieTheme.bodyFont())
                .foregroundStyle(GoosieTheme.charcoalOutline.opacity(0.6))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 20)

            Spacer()

            VStack(spacing: 12) {
                PillButton(title: "Enable Notifications", icon: "bell.fill", color: GoosieTheme.sunYellow) {
                    Task {
                        _ = try? await NotificationManager.shared.requestAuthorization()
                        completeOnboarding()
                    }
                }

                Button("Skip for now") {
                    completeOnboarding()
                }
                .font(GoosieTheme.captionFont())
                .foregroundStyle(GoosieTheme.charcoalOutline.opacity(0.5))
            }
        }
        .padding(GoosieTheme.padding)
    }

    // MARK: - Helpers

    private func nextButton(action: @escaping () -> Void) -> some View {
        PillButton(title: "Continue", icon: "arrow.right", color: GoosieTheme.coralAccent, action: action)
    }

    private func completeOnboarding() {
        // Create goose
        let goose = GooseState(name: gooseName.isEmpty ? "Harnold" : gooseName, hasCompletedOnboarding: true)
        modelContext.insert(goose)

        // Create selected goals
        for (title, _) in presetGoals where selectedGoals.contains(title) {
            let category = presetGoals.first(where: { $0.0 == title })?.1 ?? .custom
            let goal = Goal(title: title, category: category)
            modelContext.insert(goal)
        }

        // Schedule morning reminder
        NotificationManager.shared.scheduleMorningReminder(gooseName: goose.name)

        hasCompletedOnboarding = true
    }
}
