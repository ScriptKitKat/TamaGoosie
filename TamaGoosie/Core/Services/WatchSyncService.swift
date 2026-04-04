import Foundation
import WatchConnectivity

final class WatchSyncService: NSObject, WCSessionDelegate, ObservableObject {
    static let shared = WatchSyncService()

    private var session: WCSession?

    /// Whether WatchConnectivity is supported on this device (false on iPad, etc.)
    @Published private(set) var isSupported = false
    /// Whether an Apple Watch is currently paired to this iPhone.
    /// Auto-detected via WCSession — never set manually.
    @Published private(set) var isPaired = false

    private override init() {
        super.init()
    }

    func activate() {
        guard WCSession.isSupported() else {
            isSupported = false
            return
        }
        isSupported = true
        session = WCSession.default
        session?.delegate = self
        session?.activate()
    }

    // MARK: - Send Payload to Watch

    func sendPayload(_ payload: GooseSyncPayload) {
        guard let session, session.activationState == .activated else { return }
        guard let data = try? JSONEncoder().encode(payload) else { return }

        // Always update applicationContext: latest-state-wins snapshot, survives Watch relaunch
        if session.isPaired {
            try? session.updateApplicationContext(["goosePayload": data])
        }

        // Try sendMessage first (immediate delivery); fall back to transferUserInfo (queued, guaranteed)
        if session.isReachable {
            session.sendMessage(["goosePayload": data], replyHandler: nil)
        } else if session.isPaired {
            session.transferUserInfo(["goosePayload": data])
        }
    }

    // MARK: - WCSessionDelegate

    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        DispatchQueue.main.async {
            self.isPaired = (activationState == .activated) && session.isPaired
        }
    }

    func sessionDidBecomeInactive(_ session: WCSession) {}

    func sessionDidDeactivate(_ session: WCSession) {
        DispatchQueue.main.async { self.isPaired = false }
        session.activate()
    }

    /// Called when watch pairing state changes (paired/unpaired).
    func sessionWatchStateDidChange(_ session: WCSession) {
        DispatchQueue.main.async {
            self.isPaired = session.isPaired
        }
    }

    // Handle goal completion from Watch via immediate message (Watch is reachable)
    func session(_ session: WCSession, didReceiveMessage message: [String: Any], replyHandler: @escaping ([String: Any]) -> Void) {
        if let goalIDString = message["completedGoalID"] as? String,
           let _ = UUID(uuidString: goalIDString) {
            NotificationCenter.default.post(
                name: .goalCompletedFromWatch,
                object: nil,
                userInfo: ["goalID": goalIDString]
            )
        }

        // Reply with the current payload snapshot from the app group so the Watch
        // can update immediately without waiting for the next push.
        if let defaults = UserDefaults(suiteName: GoosieConstants.appGroupID),
           let data = defaults.data(forKey: GoosieConstants.gooseStatsKey) {
            replyHandler(["goosePayload": data])
        } else {
            replyHandler([:])
        }
    }

    // Handle goal completion from Watch via transferUserInfo (Watch was not reachable)
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
