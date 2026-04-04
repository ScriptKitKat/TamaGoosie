import ManagedSettings
import ManagedSettingsUI
import UIKit

class ShieldConfigurationProvider: ShieldConfigurationDataSource {
    override func configuration(shielding application: Application) -> ShieldConfiguration {
        ShieldConfiguration(
            backgroundBlurStyle: .systemUltraThinMaterial,
            backgroundColor: UIColor(red: 1.0, green: 0.97, blue: 0.94, alpha: 1.0),
            icon: nil,
            title: .init(
                text: "Harold needs you!",
                color: UIColor(red: 0.18, green: 0.18, blue: 0.18, alpha: 1.0)
            ),
            subtitle: .init(
                text: "Take a break from this app and check on your goose",
                color: UIColor(red: 0.45, green: 0.45, blue: 0.45, alpha: 1.0)
            ),
            primaryButtonLabel: .init(text: "Back to Harold", color: .white),
            primaryButtonBackgroundColor: UIColor(red: 0.72, green: 0.91, blue: 0.82, alpha: 1.0)
        )
    }
}
