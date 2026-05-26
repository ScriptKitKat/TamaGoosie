import ManagedSettings
import ManagedSettingsUI
import UIKit
import FamilyControls

class ShieldConfigurationProvider: ShieldConfigurationDataSource {

    // TamaGoosie brand palette
    private let background = UIColor(red: 0.96, green: 0.96, blue: 0.96, alpha: 1.0)         // light gray (#F5F5F5)
    private let titleColor = UIColor(red: 0.36, green: 0.29, blue: 0.23, alpha: 1.0)          // warm brown (#5C4A3A)
    private let subtitleColor = UIColor(red: 0.50, green: 0.42, blue: 0.35, alpha: 1.0)       // muted brown
    private let buttonAmber = UIColor(red: 0.91, green: 0.59, blue: 0.23, alpha: 1.0)         // amber (#E8963A)
    private let purpleAccent = UIColor(red: 0.49, green: 0.34, blue: 0.76, alpha: 1.0)        // purple

    private let defaults = UserDefaults(suiteName: "group.com.tamagoosie")!

    private var gooseName: String {
        guard let data = defaults.data(forKey: "gooseStats"),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let name = json["name"] as? String else {
            return "Your goose"
        }
        return name
    }

    private var gooseIcon: UIImage? {
        UIImage(named: "goose_shield", in: Bundle(for: Self.self), compatibleWith: nil)
    }

    // MARK: - Shield Configurations

    override func configuration(shielding application: Application) -> ShieldConfiguration {
        guard let token = application.token else { return appShield() }
        return shieldForApp(token: token)
    }

    override func configuration(shielding application: Application, in category: ActivityCategory) -> ShieldConfiguration {
        guard let token = application.token else { return appShield() }
        return shieldForApp(token: token)
    }

    override func configuration(shielding webDomain: WebDomain) -> ShieldConfiguration {
        webShield()
    }

    override func configuration(shielding webDomain: WebDomain, in category: ActivityCategory) -> ShieldConfiguration {
        webShield()
    }

    // MARK: - Lock State Resolution

    private struct MatchingLock {
        let blockID: String
        let state: LockRuntimeState
        let remaining: Int
        let duration: Int
    }

    private func matchingLocks(forApp token: ApplicationToken) -> [MatchingLock] {
        let now = Date().timeIntervalSince1970
        let blockIDs = defaults.stringArray(forKey: "activeLockBlockIDs") ?? []
        let decoder = PropertyListDecoder()

        return blockIDs.compactMap { blockID in
            guard let data = defaults.data(forKey: "blockShield-\(blockID)"),
                  let sel = try? decoder.decode(FamilyActivitySelection.self, from: data),
                  sel.applicationTokens.contains(token)
            else { return nil }

            return MatchingLock(
                blockID: blockID,
                state: LockRuntime.state(blockID: blockID, now: now, defaults: defaults),
                remaining: LockRuntime.opensRemaining(blockID: blockID, defaults: defaults),
                duration: LockRuntime.unlockDuration(blockID: blockID, defaults: defaults)
            )
        }
    }

    /// Derives shield UI from per-block lock state. Read-only — no UserDefaults writes.
    private func shieldForApp(token: ApplicationToken) -> ShieldConfiguration {
        defaults.synchronize()

        let matches = matchingLocks(forApp: token)
        guard !matches.isEmpty else { return appShield() }

        // 1. Countdown if any matching lock is in countdown
        if matches.contains(where: { if case .countdown = $0.state { return true } else { return false } }) {
            return countdownShield()
        }

        // 2. Time's up if any matching lock recently expired
        if let expired = matches.first(where: { if case .recentlyExpired = $0.state { return true } else { return false } }) {
            return timesUpShield(remaining: expired.remaining, duration: expired.duration)
        }

        // 3. Show lock UI for non-unlocked matches
        let lockedMatches = matches.filter {
            if case .unlocked = $0.state { return false }
            return true
        }

        if let locked = lockedMatches.first {
            return lockShield(remaining: locked.remaining, duration: locked.duration)
        }

        return appShield()
    }

    // MARK: - Shield Builders

    private func countdownShield() -> ShieldConfiguration {
        ShieldConfiguration(
            backgroundBlurStyle: .systemUltraThinMaterialLight,
            backgroundColor: background,
            icon: gooseIcon,
            title: .init(text: "Unlocking in 5 seconds...", color: titleColor),
            subtitle: .init(text: "\(gooseName) is giving you a moment to reconsider...", color: subtitleColor),
            primaryButtonLabel: .init(text: "Close App", color: .white),
            primaryButtonBackgroundColor: buttonAmber,
            secondaryButtonLabel: .init(text: "Cancel", color: purpleAccent)
        )
    }

    private func timesUpShield(remaining: Int, duration: Int) -> ShieldConfiguration {
        let subtitle = remaining > 0
            ? "Your \(duration)-minute break is over. \(gooseName) locked this app again."
            : "Your break is over and no unlocks are left today. See you tomorrow!"

        return buildShield(
            title: "Time's up!",
            subtitle: subtitle,
            unlockButton: remaining > 0 ? "Unlock (\(remaining) left)" : nil
        )
    }

    private func lockShield(remaining: Int, duration: Int) -> ShieldConfiguration {
        let subtitle = remaining > 0
            ? "This app is locked by \(gooseName). Tap unlock for a \(duration)-minute break."
            : "This app is locked by \(gooseName). No unlocks remaining today. Come back tomorrow!"

        return buildShield(
            title: "\(gooseName) locked this app",
            subtitle: subtitle,
            unlockButton: remaining > 0 ? "Unlock (\(remaining) left)" : nil
        )
    }

    private func buildShield(title: String, subtitle: String, unlockButton: String?) -> ShieldConfiguration {
        ShieldConfiguration(
            backgroundBlurStyle: .systemUltraThinMaterialLight,
            backgroundColor: background,
            icon: gooseIcon,
            title: .init(text: title, color: titleColor),
            subtitle: .init(text: subtitle, color: subtitleColor),
            primaryButtonLabel: .init(text: "Close App", color: .white),
            primaryButtonBackgroundColor: buttonAmber,
            secondaryButtonLabel: unlockButton.map { .init(text: $0, color: purpleAccent) }
        )
    }

    private func appShield() -> ShieldConfiguration {
        ShieldConfiguration(
            backgroundBlurStyle: .systemUltraThinMaterialLight,
            backgroundColor: background,
            icon: gooseIcon,
            title: .init(text: "Shhh... \(gooseName) is napping!", color: titleColor),
            subtitle: .init(text: "This app is blocked right now. \(gooseName) wants you to take a break and do something fun offline!", color: subtitleColor),
            primaryButtonLabel: .init(text: "Close App", color: .white),
            primaryButtonBackgroundColor: buttonAmber
        )
    }

    private func webShield() -> ShieldConfiguration {
        ShieldConfiguration(
            backgroundBlurStyle: .systemUltraThinMaterialLight,
            backgroundColor: background,
            icon: gooseIcon,
            title: .init(text: "Shhh... \(gooseName) is napping!", color: titleColor),
            subtitle: .init(text: "This site is blocked right now. Go check on \(gooseName) instead!", color: subtitleColor),
            primaryButtonLabel: .init(text: "Close", color: .white),
            primaryButtonBackgroundColor: buttonAmber
        )
    }
}
