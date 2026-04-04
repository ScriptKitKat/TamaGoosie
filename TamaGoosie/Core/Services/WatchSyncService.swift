import Foundation
import WatchConnectivity

final class WatchSyncService: NSObject, WCSessionDelegate {
    static let shared = WatchSyncService()

    private var session: WCSession?

    private override init() {
        super.init()
    }

    func activate() {
        guard WCSession.isSupported() else { return }
        session = WCSession.default
        session?.delegate = self
        session?.activate()
    }

    // MARK: - Send Payload to Watch

    func sendPayload(_ payload: GooseSyncPayload) {
        guard let session, session.activationState == .activated else { return }
        guard let data = try? JSONEncoder().encode(payload) else { return }

        // Try ApplicationContext first (persistent, delivered on next wake)
        if session.isPaired {
            try? session.updateApplicationContext(["goosePayload": data])
        }

        // Also send as message if Watch is reachable (immediate delivery)
        if session.isReachable {
            session.sendMessageData(data, replyHandler: nil)
        }
    }

    // MARK: - WCSessionDelegate

    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {}

    func sessionDidBecomeInactive(_ session: WCSession) {}

    func sessionDidDeactivate(_ session: WCSession) {
        session.activate()
    }

    // Handle goal completion from Watch
    func session(_ session: WCSession, didReceiveUserInfo userInfo: [String: Any] = [:]) {
        if let goalIDString = userInfo["completedGoalID"] as? String,
           let _ = UUID(uuidString: goalIDString) {
            NotificationCenter.default.post(
                name: .goalCompletedFromWatch,
                object: nil,
                userInfo: ["goalID": goalIDString]
            )
        }
    }
}

extension Notification.Name {
    static let goalCompletedFromWatch = Notification.Name("goalCompletedFromWatch")
}
