import SwiftUI
import ConvexMobile

struct FriendRequestSheetView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var viewModel = FriendRequestViewModel()

    var body: some View {
        NavigationStack {
            ZStack {
                GoosieTheme.mintBackground.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 20) {
                        // Search section
                        searchSection

                        // Incoming requests
                        if !viewModel.incomingRequests.isEmpty {
                            incomingSection
                        }

                        // Outgoing requests
                        if !viewModel.outgoingRequests.isEmpty {
                            outgoingSection
                        }
                    }
                    .padding(GoosieTheme.padding)
                }
            }
            .navigationTitle("Add Friends")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(GoosieTheme.coralAccent)
                }
            }
            .task {
                await viewModel.loadRequests()
            }
        }
    }

    // MARK: - Search Section

    private var searchSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(GoosieTheme.charcoalOutline.opacity(0.4))
                TextField("Search by username...", text: $viewModel.searchQuery)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .font(GoosieTheme.bodyFont(14))

                if viewModel.isSearching {
                    ProgressView()
                        .scaleEffect(0.7)
                }
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(GoosieTheme.creamWhite)
            )
            .onChange(of: viewModel.searchQuery) { _, newValue in
                viewModel.onSearchChanged(newValue)
            }

            // Search results
            if !viewModel.searchResults.isEmpty {
                VStack(spacing: 8) {
                    ForEach(viewModel.searchResults, id: \.id) { result in
                        searchResultRow(result)
                    }
                }
            } else if !viewModel.searchQuery.isEmpty && !viewModel.isSearching {
                Text("No users found")
                    .font(GoosieTheme.captionFont())
                    .foregroundStyle(GoosieTheme.charcoalOutline.opacity(0.5))
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 8)
            }
        }
    }

    private func searchResultRow(_ result: SearchResult) -> some View {
        GoosieCard {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(result.username)
                        .font(GoosieTheme.bodyFont(14))
                        .foregroundStyle(GoosieTheme.charcoalOutline)
                }

                Spacer()

                switch result.status {
                case .none:
                    Button {
                        Task { await viewModel.sendRequest(to: result) }
                    } label: {
                        Text("Add")
                            .font(GoosieTheme.captionFont(13))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 6)
                            .background(Capsule().fill(GoosieTheme.coralAccent))
                    }
                case .pendingSent:
                    Text("Pending")
                        .font(GoosieTheme.captionFont(13))
                        .foregroundStyle(GoosieTheme.charcoalOutline.opacity(0.5))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 6)
                        .background(Capsule().stroke(GoosieTheme.charcoalOutline.opacity(0.2)))
                case .pendingReceived:
                    Text("Sent you a request")
                        .font(GoosieTheme.captionFont(12))
                        .foregroundStyle(GoosieTheme.warmOrange)
                case .friends:
                    HStack(spacing: 4) {
                        Image(systemName: "checkmark")
                            .font(.system(size: 11))
                        Text("Friends")
                    }
                    .font(GoosieTheme.captionFont(13))
                    .foregroundStyle(GoosieTheme.mintBackground)
                }
            }
        }
    }

    // MARK: - Incoming Requests

    private var incomingSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Incoming Requests")
                .font(GoosieTheme.bodyFont())
                .foregroundStyle(GoosieTheme.charcoalOutline)

            ForEach(viewModel.incomingRequests, id: \.id) { request in
                GoosieCard {
                    HStack {
                        Text(request.fromUsername)
                            .font(GoosieTheme.bodyFont(14))
                            .foregroundStyle(GoosieTheme.charcoalOutline)

                        Spacer()

                        HStack(spacing: 8) {
                            Button {
                                Task { await viewModel.acceptRequest(request) }
                            } label: {
                                Text("Accept")
                                    .font(GoosieTheme.captionFont(13))
                                    .foregroundStyle(.white)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(Capsule().fill(GoosieTheme.coralAccent))
                            }

                            Button {
                                Task { await viewModel.declineRequest(request) }
                            } label: {
                                Text("Decline")
                                    .font(GoosieTheme.captionFont(13))
                                    .foregroundStyle(GoosieTheme.charcoalOutline.opacity(0.6))
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(Capsule().stroke(GoosieTheme.charcoalOutline.opacity(0.2)))
                            }
                        }
                    }
                }
            }
        }
    }

    // MARK: - Outgoing Requests

    private var outgoingSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Sent Requests")
                .font(GoosieTheme.bodyFont())
                .foregroundStyle(GoosieTheme.charcoalOutline)

            ForEach(viewModel.outgoingRequests, id: \.id) { request in
                GoosieCard {
                    HStack {
                        Text(request.toUsername)
                            .font(GoosieTheme.bodyFont(14))
                            .foregroundStyle(GoosieTheme.charcoalOutline)

                        Spacer()

                        Button {
                            Task { await viewModel.cancelRequest(request) }
                        } label: {
                            Text("Cancel")
                                .font(GoosieTheme.captionFont(13))
                                .foregroundStyle(GoosieTheme.coralAccent)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(Capsule().stroke(GoosieTheme.coralAccent.opacity(0.3)))
                        }
                    }
                }
            }
        }
    }
}
