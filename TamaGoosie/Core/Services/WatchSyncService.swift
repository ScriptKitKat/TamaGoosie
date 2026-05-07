import Foundation
import WatchConnectivity

final class WatchSyncService: NSObject, ObservableObject, WCSessionDelegate {
    static let shared = WatchSyncService()

    @Published private(set) var isWatchPaired = false

    private var session: WCSession?

    private override init() {
        super.init()
    }

    // MARK: - Activation

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

        let context: [String: Any] = ["goosePayload": data]

        // Update application context (persists, delivered on next Watch wake)
        try? session.updateApplicationContext(context)

        // Also send a live message if Watch is reachable for immediate update
        if session.isReachable {
            session.sendMessage(context, replyHandler: nil, errorHandler: nil)
        }
    }

    // MARK: - WCSessionDelegate (iPhone side)

    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        DispatchQueue.main.async {
            self.isWatchPaired = session.isPaired
        }
    }

    func sessionDidBecomeInactive(_ session: WCSession) {}

    func sessionDidDeactivate(_ session: WCSession) {
        // Re-activate for quick Watch switching
        session.activate()
    }

    func session(_ session: WCSession, didReceiveMessage message: [String: Any], replyHandler: @escaping ([String: Any]) -> Void) {
        handleIncomingMessage(message, replyHandler: replyHandler)
    }

    func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        handleIncomingMessage(message, replyHandler: nil)
    }

    func session(_ session: WCSession, didReceiveUserInfo userInfo: [String: Any] = [:]) {
        handleIncomingMessage(userInfo, replyHandler: nil)
    }

    #if os(iOS)
    func sessionWatchStateDidChange(_ session: WCSession) {
        DispatchQueue.main.async {
            self.isWatchPaired = session.isPaired
        }
    }
    #endif

    // MARK: - Handle Watch → Phone Messages

    private func handleIncomingMessage(_ message: [String: Any], replyHandler: (([String: Any]) -> Void)?) {
        if let goalIDString = message["completedGoalID"] as? String,
           let goalID = UUID(uuidString: goalIDString) {
            DispatchQueue.main.async {
                NotificationCenter.default.post(
                    name: .goalCompletedFromWatch,
                    object: nil,
                    userInfo: ["goalID": goalID, "replyHandler": replyHandler as Any]
                )
            }
        }
    }
}

extension Notification.Name {
    static let goalCompletedFromWatch = Notification.Name("goalCompletedFromWatch")
}
