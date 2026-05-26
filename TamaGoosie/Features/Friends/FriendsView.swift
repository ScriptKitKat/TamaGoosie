import SwiftUI
import ConvexMobile

struct FriendsView: View {
    @State private var viewModel = FriendsViewModel()
    @State private var showRequestSheet = false
    @State private var requestSheetTab: FriendSheetTab = .search

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                Color.clear.frame(height: 44)

                HStack(spacing: 12) {
                    Button {
                        requestSheetTab = .requests
                        showRequestSheet = true
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "person.2.fill")
                                .font(.system(size: 13, weight: .semibold))
                            Text("Pending")
                                .font(.system(size: 13, weight: .bold, design: .rounded))
                            Text("\(viewModel.pendingCount)")
                                .font(.system(size: 11, weight: .heavy, design: .rounded))
                                .foregroundStyle(viewModel.pendingCount > 0 ? .white : Color(hex: 0x43A047).opacity(0.6))
                                .frame(width: 20, height: 20)
                                .background(
                                    Circle().fill(viewModel.pendingCount > 0 ? Color(hex: 0xEF5350) : Color(hex: 0x43A047).opacity(0.1))
                                )
                        }
                        .foregroundStyle(Color(hex: 0x43A047))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(
                            Capsule()
                                .fill(Color(hex: 0x43A047).opacity(0.1))
                                .overlay(
                                    Capsule()
                                        .strokeBorder(Color(hex: 0x43A047).opacity(0.25), lineWidth: 1)
                                )
                        )
                    }

                    Spacer()

                    Button {
                        requestSheetTab = .search
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
                }
                .padding(.horizontal, GoosieTheme.padding)
                .padding(.top, 8)

                gooseBanner
                    .padding(.top, 12)

                if viewModel.isLoading {
                    ProgressView("Loading friends...")
                        .font(GoosieTheme.captionFont())
                        .padding(.top, 60)
                } else if viewModel.friends.isEmpty {
                    emptyState
                } else {
                    friendsListContent
                }
            }
        }
        .background(Color(hex: 0xF5F5F0).ignoresSafeArea())
        .refreshable { await viewModel.refresh() }
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
        .task { await viewModel.startListening() }
        .sheet(isPresented: $showRequestSheet) {
            FriendRequestSheetView(selectedTab: requestSheetTab)
        }
    }

    private var gooseBanner: some View {
        ZStack {
            Image("goose_pals_banner")
                .resizable()
                .aspectRatio(contentMode: .fill)
            Text("Goose Pals")
                .font(.custom("Slackey", size: 26))
                .foregroundStyle(.white)
                .shadow(color: .black.opacity(0.5), radius: 6, y: 2)
        }
        .frame(height: 120)
        .clipped()
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .contentShape(RoundedRectangle(cornerRadius: 16))
        .padding(.horizontal, GoosieTheme.padding)
    }

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

            Divider().padding(.horizontal, GoosieTheme.padding)

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
                    requestSheetTab = .search
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

    private var friendsListContent: some View {
        VStack(spacing: 0) {
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

            bettingSection
                .padding(.top, 24)
                .padding(.bottom, 20)
        }
    }

    private var bettingSection: some View {
        VStack(spacing: 0) {
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
                    .background(Capsule().fill(Color(hex: 0xF5A623).opacity(0.12)))
            }
            .padding(.horizontal, GoosieTheme.padding)

            Divider()
                .padding(.horizontal, GoosieTheme.padding)
                .padding(.top, 8)

            VStack(spacing: 12) {
                betCardPlaceholder(challenger: "You", opponent: "???", goal: "Walk 10,000 steps", wager: 50)
                betCardPlaceholder(challenger: "???", opponent: "You", goal: "Sleep 8 hours", wager: 30)
            }
            .padding(.horizontal, GoosieTheme.padding)
            .padding(.top, 12)

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
            ZStack {
                Circle().fill(Color(hex: 0xFFF3B0)).frame(width: 40, height: 40)
                Image(systemName: "dollarsign.circle.fill")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(Color(hex: 0xF5A623))
            }
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 4) {
                    Text(challenger).font(.system(size: 14, weight: .bold, design: .rounded)).foregroundStyle(GoosieTheme.charcoalOutline)
                    Text("vs").font(.system(size: 12, weight: .medium)).foregroundStyle(GoosieTheme.charcoalOutline.opacity(0.4))
                    Text(opponent).font(.system(size: 14, weight: .bold, design: .rounded)).foregroundStyle(GoosieTheme.charcoalOutline)
                }
                Text(goal).font(.system(size: 12)).foregroundStyle(GoosieTheme.charcoalOutline.opacity(0.5))
            }
            Spacer()
            HStack(spacing: 3) {
                Image(systemName: "dollarsign.circle.fill").font(.system(size: 12)).foregroundStyle(Color(hex: 0xF5A623))
                Text("\(wager)").font(.system(size: 14, weight: .heavy, design: .rounded)).foregroundStyle(Color(hex: 0xF5A623))
            }
            .padding(.horizontal, 10).padding(.vertical, 5)
            .background(Capsule().fill(Color(hex: 0xF5A623).opacity(0.12)))
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 14).fill(.white).shadow(color: .black.opacity(0.05), radius: 3, y: 1))
        .opacity(0.6)
    }
}
