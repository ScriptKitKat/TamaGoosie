import Foundation

// Watch sync disabled — auto-detect and pairing removed.
// Re-enable by restoring WatchConnectivity session logic here.
final class WatchSyncService: ObservableObject {
    static let shared = WatchSyncService()
    private init() {}

    func activate() {}
    func sendPayload(_ payload: GooseSyncPayload) {}
}

extension Notification.Name {
    static let goalCompletedFromWatch = Notification.Name("goalCompletedFromWatch")
}
