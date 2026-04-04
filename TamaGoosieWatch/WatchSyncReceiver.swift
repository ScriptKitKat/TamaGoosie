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
        guard let session else { return }

        if session.isReachable {
            session.sendMessage(
                ["completedGoalID": goalID.uuidString],
                replyHandler: { [weak self] reply in
                    // If phone replies with an updated payload, apply it immediately
                    if let data = reply["goosePayload"] as? Data,
                       let payload = try? JSONDecoder().decode(GooseSyncPayload.self, from: data) {
                        DispatchQueue.main.async {
                            self?.currentPayload = payload
                        }
                    }
                },
                errorHandler: { _ in
                    // sendMessage failed; queue for guaranteed delivery
                    session.transferUserInfo(["completedGoalID": goalID.uuidString])
                }
            )
        } else {
            session.transferUserInfo(["completedGoalID": goalID.uuidString])
        }
    }

    // MARK: - WCSessionDelegate

    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {}

    // Receives payload pushed via updateApplicationContext (persistent, survives relaunch)
    func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String: Any]) {
        if let data = applicationContext["goosePayload"] as? Data,
           let payload = try? JSONDecoder().decode(GooseSyncPayload.self, from: data) {
            DispatchQueue.main.async {
                self.currentPayload = payload
            }
        }
    }

    // Receives payload pushed via transferUserInfo (queued, guaranteed delivery)
    func session(_ session: WCSession, didReceiveUserInfo userInfo: [String: Any] = [:]) {
        if let data = userInfo["goosePayload"] as? Data,
           let payload = try? JSONDecoder().decode(GooseSyncPayload.self, from: data) {
            DispatchQueue.main.async {
                self.currentPayload = payload
            }
        }
    }

    // Receives payload pushed via sendMessage (immediate delivery)
    func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        if let data = message["goosePayload"] as? Data,
           let payload = try? JSONDecoder().decode(GooseSyncPayload.self, from: data) {
            DispatchQueue.main.async {
                self.currentPayload = payload
            }
        }
    }
}
