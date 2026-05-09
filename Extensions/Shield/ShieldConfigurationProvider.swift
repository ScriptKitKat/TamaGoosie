import ManagedSettings
import ManagedSettingsUI
import UIKit

class ShieldConfigurationProvider: ShieldConfigurationDataSource {
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
            backgroundBlurStyle: .systemUltraThinMaterial,
            backgroundColor: UIColor(red: 1.0, green: 0.97, blue: 0.94, alpha: 1.0),
            icon: nil,
            title: .init(
                text: "\(gooseName) needs you!",
                color: UIColor(red: 0.18, green: 0.18, blue: 0.18, alpha: 1.0)
            ),
            subtitle: .init(
                text: "Take a break and check on \(gooseName)",
                color: UIColor(red: 0.45, green: 0.45, blue: 0.45, alpha: 1.0)
            ),
            primaryButtonLabel: .init(text: "Back to \(gooseName)", color: .white),
            primaryButtonBackgroundColor: UIColor(red: 0.72, green: 0.91, blue: 0.82, alpha: 1.0)
        )
    }
}
