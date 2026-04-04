import Foundation
import WatchConnectivity
import Observation

@Observable
final class WatchSyncReceiver: NSObject, WCSessionDelegate {
    static let shared = WatchSyncReceiver()

    var currentStats = GooseStats()
    var activeGoals: [GoalSummary] = []

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
            // Queue via userInfo if phone not reachable
            session?.transferUserInfo(["completedGoalID": goalID.uuidString])
            return
        }

        session.sendMessage(["completedGoalID": goalID.uuidString], replyHandler: nil)
    }

    // MARK: - WCSessionDelegate

    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {}

    func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String: Any]) {
        if let data = applicationContext["gooseStats"] as? Data,
           let stats = try? JSONDecoder().decode(GooseStats.self, from: data) {
            DispatchQueue.main.async {
                self.currentStats = stats
            }
        }
    }

    func session(_ session: WCSession, didReceiveUserInfo userInfo: [String: Any] = [:]) {
        if let data = userInfo["goals"] as? Data,
           let goals = try? JSONDecoder().decode([GoalSummary].self, from: data) {
            DispatchQueue.main.async {
                self.activeGoals = goals
            }
        }
    }

    func session(_ session: WCSession, didReceiveMessageData messageData: Data) {
        if let stats = try? JSONDecoder().decode(GooseStats.self, from: messageData) {
            DispatchQueue.main.async {
                self.currentStats = stats
            }
        }
    }
}
