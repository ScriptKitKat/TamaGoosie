import Foundation
import Observation

@Observable
final class FocusTimer {
    var targetMinutes: Int
    var remainingSeconds: Int
    var isRunning = false
    var isCompleted = false

    private var timer: Timer?

    var progress: Double {
        let total = Double(targetMinutes * 60)
        guard total > 0 else { return 0 }
        return 1.0 - (Double(remainingSeconds) / total)
    }

    var displayTime: String {
        let minutes = remainingSeconds / 60
        let seconds = remainingSeconds % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }

    var elapsedMinutes: Int {
        (targetMinutes * 60 - remainingSeconds) / 60
    }

    init(minutes: Int = GoosieConstants.focusDefaultMinutes) {
        self.targetMinutes = minutes
        self.remainingSeconds = minutes * 60
    }

    func start() {
        guard !isRunning else { return }
        isRunning = true
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            guard let self else { return }
            if self.remainingSeconds > 0 {
                self.remainingSeconds -= 1
            } else {
                self.complete()
            }
        }
    }

    func pause() {
        isRunning = false
        timer?.invalidate()
        timer = nil
    }

    func reset() {
        pause()
        remainingSeconds = targetMinutes * 60
        isCompleted = false
    }

    func setDuration(_ minutes: Int) {
        let clamped = max(GoosieConstants.focusMinMinutes, min(GoosieConstants.focusMaxMinutes, minutes))
        targetMinutes = clamped
        remainingSeconds = clamped * 60
    }

    private func complete() {
        pause()
        isCompleted = true
    }
}
