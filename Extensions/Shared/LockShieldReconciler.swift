import Foundation
import ManagedSettings
import FamilyControls

/// Single source of truth for lock-block shields.
///
/// All lock blocks share one `ManagedSettingsStore` (the default store).
/// Every process that changes lock state calls `reconcile()` to recompute
/// which apps should currently be shielded.
///
/// Used by: ShieldActionHandler, DeviceActivityMonitorExtension, ScreenTimeManager.
enum LockShieldReconciler {

    /// Recompute the default store's shield from all active lock blocks,
    /// skipping any that are temporarily unlocked.
    static func reconcile() {
        let defaults = UserDefaults(suiteName: "group.com.tamagoosie")!
        defaults.synchronize()

        let lockIDs = defaults.stringArray(forKey: "activeLockBlockIDs") ?? []
        let store = ManagedSettingsStore()

        var allApps = Set<ApplicationToken>()
        var allCats = Set<ActivityCategoryToken>()
        var allWebs = Set<WebDomainToken>()

        var shielded: [String] = []
        var skipped: [String] = []

        for lockID in lockIDs {
            let short = String(lockID.prefix(8))

            // Skip temporarily unlocked blocks
            let expiryTS = defaults.double(forKey: "lockUnlockExpiry-\(lockID)")
            if expiryTS > 0 && Date().timeIntervalSince1970 < expiryTS {
                skipped.append(short)
                continue
            }

            guard let data = defaults.data(forKey: "blockShield-\(lockID)"),
                  let sel = try? PropertyListDecoder().decode(FamilyActivitySelection.self, from: data)
            else { continue }

            allApps.formUnion(sel.applicationTokens)
            allCats.formUnion(sel.categoryTokens)
            allWebs.formUnion(sel.webDomainTokens)
            shielded.append(short)
        }

        store.shield.applications = allApps.isEmpty ? nil : allApps
        store.shield.applicationCategories = allCats.isEmpty ? nil : .specific(allCats)
        store.shield.webDomains = allWebs.isEmpty ? nil : allWebs

        log("reconcile: shielded=\(shielded) skipped=\(skipped) apps=\(allApps.count) cats=\(allCats.count) webs=\(allWebs.count)", defaults: defaults)
    }

    private static let isoFormatter = ISO8601DateFormatter()

    private static func log(_ msg: String, defaults: UserDefaults) {
        let ts = isoFormatter.string(from: Date())
        var crumbs = defaults.stringArray(forKey: "extensionBreadcrumbs") ?? []
        crumbs.append("[\(ts)] LockReconciler: \(msg)")
        if crumbs.count > 50 { crumbs = Array(crumbs.suffix(50)) }
        defaults.set(crumbs, forKey: "extensionBreadcrumbs")
        defaults.set(Date().timeIntervalSince1970, forKey: "extensionLastCallback")
        defaults.synchronize()
    }
}
