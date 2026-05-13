import SwiftUI
import ConvexMobile

struct FriendsView: View {
    @State private var viewModel = FriendsViewModel()
    @State private var showRequestSheet = false

    var body: some View {
        ZStack {
            Color(hex: 0xF5F5F0)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // Top action buttons
                HStack(spacing: 12) {
                    Spacer()

                    Button {
                        showRequestSheet = true
                    } label: {
                        Image(systemName: "person.badge.plus")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(Color(hex: 0x43A047))
                            .frame(width: 40, height: 40)
                            .background(
                                Circle()
                                    .strokeBorder(Color(hex: 0x43A047).opacity(0.3), lineWidth: 1.5)
                            )
                    }

                    if viewModel.pendingCount > 0 {
                        Button {
                            showRequestSheet = true
                        } label: {
                            Image(systemName: "person.text.rectangle")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundStyle(Color(hex: 0x43A047))
                                .frame(width: 40, height: 40)
                                .background(
                                    Circle()
                                        .strokeBorder(Color(hex: 0x43A047).opacity(0.3), lineWidth: 1.5)
                                )
                                .overlay(alignment: .topTrailing) {
                                    Text("\(viewModel.pendingCount)")
                                        .font(.system(size: 10, weight: .bold))
                                        .foregroundStyle(.white)
                                        .frame(width: 18, height: 18)
                                        .background(Circle().fill(Color(hex: 0xEF5350)))
                                        .offset(x: 4, y: -4)
                                }
                        }
                    }
                }
                .padding(.horizontal, GoosieTheme.padding)
                .padding(.top, 52)

                // Goose banner
                gooseBanner
                    .padding(.top, 12)

                // Content
                if viewModel.isLoading {
                    Spacer()
                    ProgressView("Loading friends...")
                        .font(GoosieTheme.captionFont())
                    Spacer()
                } else if viewModel.friends.isEmpty {
                    emptyState
                    Spacer()
                } else {
                    friendsContent
                }
            }
        }
        .sheet(isPresented: $showRequestSheet) {
            FriendRequestSheetView()
        }
        .task {
            await viewModel.startListening()
        }
        .refreshable {
            await viewModel.refresh()
        }
    }

    // MARK: - Goose Banner

    private var gooseBanner: some View {
        ZStack {
            // Soft pond gradient
            RoundedRectangle(cornerRadius: 16)
                .fill(
                    LinearGradient(
                        colors: [Color(hex: 0xE0F2F1), Color(hex: 0xB2DFDB), Color(hex: 0xC8E6C9)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            // Title
            VStack(spacing: 4) {
                Text("Goose Pals")
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundStyle(Color(hex: 0x2E7D32))

                // Wave accent
                HStack(spacing: 6) {
                    WaveAccent()
                        .stroke(Color(hex: 0x4DB6AC).opacity(0.5), lineWidth: 2)
                        .frame(width: 30, height: 6)

                    Circle()
                        .fill(Color(hex: 0x4DB6AC).opacity(0.4))
                        .frame(width: 4, height: 4)

                    WaveAccent()
                        .stroke(Color(hex: 0x4DB6AC).opacity(0.5), lineWidth: 2)
                        .frame(width: 30, height: 6)
                }
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay {
            ZStack {
                // Lily pad accents (clipped inside)
                Ellipse()
                    .fill(Color(hex: 0x81C784).opacity(0.2))
                    .frame(width: 60, height: 28)
                    .offset(x: -110, y: 25)

                Ellipse()
                    .fill(Color(hex: 0x81C784).opacity(0.15))
                    .frame(width: 45, height: 20)
                    .offset(x: 100, y: -20)

                Ellipse()
                    .fill(Color(hex: 0xA5D6A7).opacity(0.25))
                    .frame(width: 55, height: 22)
                    .offset(x: 70, y: 30)

                // Ripple rings
                Circle()
                    .strokeBorder(Color(hex: 0x80CBC4).opacity(0.3), lineWidth: 1)
                    .frame(width: 22, height: 22)
                    .offset(x: -55, y: -18)

                Circle()
                    .strokeBorder(Color(hex: 0x80CBC4).opacity(0.2), lineWidth: 1)
                    .frame(width: 14, height: 14)
                    .offset(x: -45, y: -8)

                Circle()
                    .strokeBorder(Color(hex: 0x80CBC4).opacity(0.25), lineWidth: 1)
                    .frame(width: 18, height: 18)
                    .offset(x: 35, y: 12)
            }
            .clipShape(RoundedRectangle(cornerRadius: 16))
        }
        .frame(height: 100)
        .padding(.horizontal, GoosieTheme.padding)
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 16) {
            HStack {
                Text("Friends")
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundStyle(GoosieTheme.charcoalOutline)

                Text("0/0")
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(Capsule().fill(Color(hex: 0x43A047)))

                Spacer()
            }
            .padding(.horizontal, GoosieTheme.padding)
            .padding(.top, 16)

            Divider()
                .padding(.horizontal, GoosieTheme.padding)

            VStack(spacing: 12) {
                Image(systemName: "person.2.slash")
                    .font(.system(size: 36))
                    .foregroundStyle(GoosieTheme.charcoalOutline.opacity(0.25))

                Text("No friends yet!")
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                    .foregroundStyle(GoosieTheme.charcoalOutline.opacity(0.6))

                Text("Tap the + button to search\nand add friends")
                    .font(.system(size: 13))
                    .foregroundStyle(GoosieTheme.charcoalOutline.opacity(0.4))
                    .multilineTextAlignment(.center)

                Button {
                    showRequestSheet = true
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "person.badge.plus")
                            .font(.system(size: 14, weight: .bold))
                        Text("Add Friends")
                            .font(.system(size: 14, weight: .heavy, design: .rounded))
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(Capsule().fill(Color(hex: 0x43A047)))
                }
            }
            .padding(.top, 20)
        }
    }

    // MARK: - Friends Content (list + bets)

    private var friendsContent: some View {
        ScrollView {
            VStack(spacing: 0) {
                // Friends section header
                HStack {
                    Text("Friends")
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .foregroundStyle(GoosieTheme.charcoalOutline)

                    Text("\(viewModel.friends.count)")
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(Capsule().fill(Color(hex: 0x43A047)))

                    Spacer()
                }
                .padding(.horizontal, GoosieTheme.padding)
                .padding(.top, 16)

                // Green accent + subtitle
                HStack(spacing: 8) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color(hex: 0x43A047))
                        .frame(width: 4, height: 16)

                    Text("Your Goose Friends")
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .foregroundStyle(GoosieTheme.charcoalOutline.opacity(0.7))

                    Spacer()
                }
                .padding(.horizontal, GoosieTheme.padding)
                .padding(.top, 12)

                Divider()
                    .padding(.horizontal, GoosieTheme.padding)
                    .padding(.top, 8)

                // Friend cards
                LazyVStack(spacing: 0) {
                    ForEach(viewModel.friends, id: \.id) { friend in
                        FriendCardView(friend: friend) {
                            viewModel.friendToRemove = friend
                            viewModel.showRemoveConfirmation = true
                        }

                        if friend.id != viewModel.friends.last?.id {
                            Divider()
                                .padding(.leading, 80)
                                .padding(.horizontal, GoosieTheme.padding)
                        }
                    }
                }
                .padding(.top, 8)

                // Betting section
                bettingSection
                    .padding(.top, 24)
                    .padding(.bottom, 20)
            }
            .trackScrollOffset()
        }
        .alert("Remove Friend?", isPresented: $viewModel.showRemoveConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Remove", role: .destructive) {
                if let friend = viewModel.friendToRemove {
                    Task { await viewModel.removeFriend(friend) }
                }
            }
        } message: {
            if let friend = viewModel.friendToRemove {
                Text("Remove \(friend.username) from your friends?")
            }
        }
    }

    // MARK: - Betting Section

    private var bettingSection: some View {
        VStack(spacing: 0) {
            // Section header
            HStack(spacing: 8) {
                RoundedRectangle(cornerRadius: 2)
                    .fill(Color(hex: 0xF5A623))
                    .frame(width: 4, height: 16)

                Text("Goal Bets")
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundStyle(GoosieTheme.charcoalOutline.opacity(0.7))

                Spacer()

                Text("Coming Soon")
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundStyle(Color(hex: 0xF5A623))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(
                        Capsule()
                            .fill(Color(hex: 0xF5A623).opacity(0.12))
                    )
            }
            .padding(.horizontal, GoosieTheme.padding)

            Divider()
                .padding(.horizontal, GoosieTheme.padding)
                .padding(.top, 8)

            // Active bets placeholder
            VStack(spacing: 12) {
                // Bet card placeholder
                betCardPlaceholder(
                    challenger: "You",
                    opponent: "???",
                    goal: "Walk 10,000 steps",
                    wager: 50
                )

                betCardPlaceholder(
                    challenger: "???",
                    opponent: "You",
                    goal: "Sleep 8 hours",
                    wager: 30
                )
            }
            .padding(.horizontal, GoosieTheme.padding)
            .padding(.top, 12)

            // Create bet button
            Button {} label: {
                HStack(spacing: 8) {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 16, weight: .bold))
                    Text("Challenge a Friend")
                        .font(.system(size: 14, weight: .heavy, design: .rounded))
                }
                .foregroundStyle(Color(hex: 0xF5A623))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(
                    RoundedRectangle(cornerRadius: 14)
                        .fill(Color(hex: 0xF5A623).opacity(0.08))
                        .overlay(
                            RoundedRectangle(cornerRadius: 14)
                                .strokeBorder(Color(hex: 0xF5A623).opacity(0.25), style: StrokeStyle(lineWidth: 1.5, dash: [6, 4]))
                        )
                )
            }
            .disabled(true)
            .padding(.horizontal, GoosieTheme.padding)
            .padding(.top, 12)
        }
    }

    private func betCardPlaceholder(challenger: String, opponent: String, goal: String, wager: Int) -> some View {
        HStack(spacing: 12) {
            // Coin icon
            ZStack {
                Circle()
                    .fill(Color(hex: 0xFFF3B0))
                    .frame(width: 40, height: 40)
                Image(systemName: "dollarsign.circle.fill")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(Color(hex: 0xF5A623))
            }

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 4) {
                    Text(challenger)
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundStyle(GoosieTheme.charcoalOutline)
                    Text("vs")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(GoosieTheme.charcoalOutline.opacity(0.4))
                    Text(opponent)
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundStyle(GoosieTheme.charcoalOutline)
                }

                Text(goal)
                    .font(.system(size: 12))
                    .foregroundStyle(GoosieTheme.charcoalOutline.opacity(0.5))
            }

            Spacer()

            // Wager amount
            HStack(spacing: 3) {
                Image(systemName: "dollarsign.circle.fill")
                    .font(.system(size: 12))
                    .foregroundStyle(Color(hex: 0xF5A623))
                Text("\(wager)")
                    .font(.system(size: 14, weight: .heavy, design: .rounded))
                    .foregroundStyle(Color(hex: 0xF5A623))
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(
                Capsule()
                    .fill(Color(hex: 0xF5A623).opacity(0.12))
            )
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(.white)
                .shadow(color: .black.opacity(0.05), radius: 3, y: 1)
        )
        .opacity(0.6)
    }
}

// MARK: - Wave Accent Shape

private struct WaveAccent: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let w = rect.width
        let h = rect.height
        path.move(to: CGPoint(x: 0, y: h * 0.5))
        path.addCurve(
            to: CGPoint(x: w, y: h * 0.5),
            control1: CGPoint(x: w * 0.3, y: -h * 0.5),
            control2: CGPoint(x: w * 0.7, y: h * 1.5)
        )
        return path
    }
}
