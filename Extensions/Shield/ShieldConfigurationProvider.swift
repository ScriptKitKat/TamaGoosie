import ManagedSettings
import ManagedSettingsUI
import UIKit

class ShieldConfigurationProvider: ShieldConfigurationDataSource {

    // TamaGoosie brand palette
    private let background = UIColor(red: 0.96, green: 0.96, blue: 0.96, alpha: 1.0)         // light gray (#F5F5F5)
    private let titleColor = UIColor(red: 0.36, green: 0.29, blue: 0.23, alpha: 1.0)          // warm brown (#5C4A3A)
    private let subtitleColor = UIColor(red: 0.50, green: 0.42, blue: 0.35, alpha: 1.0)       // muted brown
    private let buttonAmber = UIColor(red: 0.91, green: 0.59, blue: 0.23, alpha: 1.0)         // amber (#E8963A)
    private let buttonTextBrown = UIColor(red: 0.36, green: 0.29, blue: 0.23, alpha: 1.0)     // warm brown

    private var gooseName: String {
        let defaults = UserDefaults(suiteName: "group.com.tamagoosie")
        guard let data = defaults?.data(forKey: "gooseStats"),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let name = json["name"] as? String else {
            return "Your goose"
        }
        return name
    }

    private var gooseIcon: UIImage? {
        UIImage(named: "goose_shield", in: Bundle(for: Self.self), compatibleWith: nil)
    }

    private func appShield() -> ShieldConfiguration {
        ShieldConfiguration(
            backgroundBlurStyle: .systemUltraThinMaterialLight,
            backgroundColor: background,
            icon: gooseIcon,
            title: .init(
                text: "Shhh... \(gooseName) is napping!",
                color: titleColor
            ),
            subtitle: .init(
                text: "This app is blocked right now. \(gooseName) wants you to take a break and do something fun offline!",
                color: subtitleColor
            ),
            primaryButtonLabel: .init(text: "Close App", color: .white),
            primaryButtonBackgroundColor: buttonAmber
        )
    }

    private func webShield() -> ShieldConfiguration {
        ShieldConfiguration(
            backgroundBlurStyle: .systemUltraThinMaterialLight,
            backgroundColor: background,
            icon: gooseIcon,
            title: .init(
                text: "Shhh... \(gooseName) is napping!",
                color: titleColor
            ),
            subtitle: .init(
                text: "This site is blocked right now. Go check on \(gooseName) instead!",
                color: subtitleColor
            ),
            primaryButtonLabel: .init(text: "Close", color: .white),
            primaryButtonBackgroundColor: buttonAmber
        )
    }

    override func configuration(shielding application: Application) -> ShieldConfiguration {
        appShield()
    }

    override func configuration(shielding application: Application, in category: ActivityCategory) -> ShieldConfiguration {
        appShield()
    }

    override func configuration(shielding webDomain: WebDomain) -> ShieldConfiguration {
        webShield()
    }

    override func configuration(shielding webDomain: WebDomain, in category: ActivityCategory) -> ShieldConfiguration {
        webShield()
    }
}
