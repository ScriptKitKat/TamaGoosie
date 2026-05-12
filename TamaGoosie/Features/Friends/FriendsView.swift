import SwiftUI
import ConvexMobile

struct FriendsView: View {
    @State private var viewModel = FriendsViewModel()
    @State private var showRequestSheet = false

    var body: some View {
        ZStack {
            GoosieTheme.mintBackground.ignoresSafeArea()

            VStack(spacing: 0) {
                // Add friend button
                HStack {
                    Spacer()

                    Button {
                        showRequestSheet = true
                    } label: {
                        Image(systemName: "person.badge.plus")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundStyle(GoosieTheme.coralAccent)
                            .frame(width: 44, height: 44)
                            .background(
                                Circle()
                                    .fill(GoosieTheme.coralAccent.opacity(0.12))
                            )
                    }
                }
                .padding(.horizontal, GoosieTheme.padding)
                .padding(.top, 8)

                // Pending requests badge
                if viewModel.pendingCount > 0 {
                    Button {
                        showRequestSheet = true
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "bell.fill")
                                .font(.system(size: 12))
                            Text("\(viewModel.pendingCount) pending request\(viewModel.pendingCount == 1 ? "" : "s")")
                                .font(GoosieTheme.captionFont(13))
                        }
                        .foregroundStyle(.white)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(Capsule().fill(GoosieTheme.coralAccent))
                    }
                    .padding(.top, 8)
                }

                // Content
                if viewModel.isLoading {
                    Spacer()
                    ProgressView("Loading friends...")
                        .font(GoosieTheme.captionFont())
                    Spacer()
                } else if viewModel.friends.isEmpty {
                    Spacer()
                    emptyState
                    Spacer()
                } else {
                    friendsList
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

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 16) {
            GooseCharacterView(mood: .content)
                .frame(height: 200)

            Text("No friends yet!")
                .font(GoosieTheme.bodyFont())
                .foregroundStyle(GoosieTheme.charcoalOutline)

            Text("Tap the + button to search\nand add friends")
                .font(GoosieTheme.captionFont())
                .foregroundStyle(GoosieTheme.charcoalOutline.opacity(0.5))
                .multilineTextAlignment(.center)

            PillButton(title: "Add Friends", icon: "person.badge.plus", color: GoosieTheme.coralAccent) {
                showRequestSheet = true
            }
        }
    }

    // MARK: - Friends List

    private var friendsList: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(viewModel.friends, id: \.id) { friend in
                    FriendCardView(friend: friend) {
                        viewModel.friendToRemove = friend
                        viewModel.showRemoveConfirmation = true
                    }
                }
            }
            .padding(.horizontal, GoosieTheme.padding)
            .padding(.top, 12)
            .padding(.bottom, 20)
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
}
