import ManagedSettings
import ManagedSettingsUI
import UIKit

class ShieldConfigurationProvider: ShieldConfigurationDataSource {

    // Pokemon Sleep-inspired night sky palette
    private let nightBackground = UIColor(red: 0.12, green: 0.15, blue: 0.28, alpha: 1.0)    // deep navy
    private let titleColor = UIColor(red: 0.95, green: 0.92, blue: 0.82, alpha: 1.0)          // warm cream
    private let subtitleColor = UIColor(red: 0.70, green: 0.72, blue: 0.85, alpha: 1.0)       // soft lavender
    private let buttonGreen = UIColor(red: 0.42, green: 0.68, blue: 0.53, alpha: 1.0)         // sage green

    private var gooseName: String {
        let defaults = UserDefaults(suiteName: "group.com.tamagoosie")
        guard let data = defaults?.data(forKey: "gooseStats"),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let name = json["name"] as? String else {
            return "Your goose"
        }
        return name
    }

    override func configuration(shielding application: Application) -> ShieldConfiguration {
        ShieldConfiguration(
            backgroundBlurStyle: .systemThickMaterialDark,
            backgroundColor: nightBackground,
            icon: nil,
            title: .init(
                text: "\(gooseName) is sleeping...",
                color: titleColor
            ),
            subtitle: .init(
                text: "Shhh! \(gooseName) is resting. Come back later and let your goose recharge.",
                color: subtitleColor
            ),
            primaryButtonLabel: .init(text: "Back to \(gooseName)", color: .white),
            primaryButtonBackgroundColor: buttonGreen
        )
    }

    override func configuration(shielding application: Application, in category: ActivityCategory) -> ShieldConfiguration {
        configuration(shielding: application)
    }

    override func configuration(shielding webDomain: WebDomain) -> ShieldConfiguration {
        ShieldConfiguration(
            backgroundBlurStyle: .systemThickMaterialDark,
            backgroundColor: nightBackground,
            icon: nil,
            title: .init(
                text: "\(gooseName) is sleeping...",
                color: titleColor
            ),
            subtitle: .init(
                text: "This site is blocked right now. Go check on \(gooseName) instead!",
                color: subtitleColor
            ),
            primaryButtonLabel: .init(text: "Back to \(gooseName)", color: .white),
            primaryButtonBackgroundColor: buttonGreen
        )
    }

    override func configuration(shielding webDomain: WebDomain, in category: ActivityCategory) -> ShieldConfiguration {
        configuration(shielding: webDomain)
    }
}
