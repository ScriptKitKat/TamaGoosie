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

    // MARK: - WCSessionDelegate

    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        // Activation complete
    }

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
