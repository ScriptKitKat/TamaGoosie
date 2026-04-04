import Foundation
import WatchConnectivity
import Observation

@Observable
final class WatchSyncReceiver: NSObject, WCSessionDelegate {
    static let shared = WatchSyncReceiver()

    var currentPayload = GooseSyncPayload()
    var activeGoals: [GoalSummary] {
        currentPayload.topGoals
    }

    private var session: WCSession?

    private override init() {
        super.init()
        activate()
    }

    func activate() {
        guard WCSession.isSupported() else { return }
        session = WCSession.default
        session?.delegate = self
        session?.activate()
    }

    // MARK: - Send Goal Completion to Phone

    func sendGoalCompletion(goalID: UUID) {
        guard let session, session.isReachable else {
            session?.transferUserInfo(["completedGoalID": goalID.uuidString])
            return
        }

        session.sendMessage(["completedGoalID": goalID.uuidString], replyHandler: nil)
    }

    // MARK: - WCSessionDelegate

    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {}

    func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String: Any]) {
        if let data = applicationContext["goosePayload"] as? Data,
           let payload = try? JSONDecoder().decode(GooseSyncPayload.self, from: data) {
            DispatchQueue.main.async {
                self.currentPayload = payload
            }
        }
    }

    func session(_ session: WCSession, didReceiveUserInfo userInfo: [String: Any] = [:]) {
        if let data = userInfo["goosePayload"] as? Data,
           let payload = try? JSONDecoder().decode(GooseSyncPayload.self, from: data) {
            DispatchQueue.main.async {
                self.currentPayload = payload
            }
        }
    }

    func session(_ session: WCSession, didReceiveMessageData messageData: Data) {
        if let payload = try? JSONDecoder().decode(GooseSyncPayload.self, from: messageData) {
            DispatchQueue.main.async {
                self.currentPayload = payload
            }
        }
    }
}
