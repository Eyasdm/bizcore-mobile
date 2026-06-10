import SwiftUI
import UserNotifications

// MARK: - NotificationViewModel
@MainActor
@Observable
final class NotificationViewModel {

    // MARK: - UserDefaults Keys
    // Shared with BackgroundRefresh, which reads these same keys directly while
    // the app is suspended — keep the strings in sync if they ever change.
    private enum Key {
        static let checkFrequency = "checkFrequencyHours"
        static let quietStart     = "quietStartHour"
        static let quietEnd       = "quietEndHour"
        static let lowStock       = "lowStockAlertsEnabled"
        static let critical       = "criticalAlertsEnabled"
        static let lastChecked    = "lastCheckedTimestamp"
    }

    private let defaults = UserDefaults.standard

    // MARK: - Persisted Settings
    // @Observable is INCOMPATIBLE with @AppStorage on stored properties: the macro
    // rewrites stored properties into computed ones, and a property wrapper can't be
    // applied to a computed property (the previous version would not compile).
    // Plain stored properties keep SwiftUI observation working, and each didSet
    // mirrors the change into UserDefaults so settings survive relaunch. Initial
    // values load once in init(); didSet does not fire for that initial assignment,
    // so there is no redundant write at startup.
    var checkFrequencyHours: Int {
        didSet { defaults.set(checkFrequencyHours, forKey: Key.checkFrequency) }
    }
    var quietStartHour: Int {
        didSet { defaults.set(quietStartHour, forKey: Key.quietStart) }
    }
    var quietEndHour: Int {
        didSet { defaults.set(quietEndHour, forKey: Key.quietEnd) }
    }
    var lowStockAlertsEnabled: Bool {
        didSet { defaults.set(lowStockAlertsEnabled, forKey: Key.lowStock) }
    }
    var criticalAlertsEnabled: Bool {
        didSet { defaults.set(criticalAlertsEnabled, forKey: Key.critical) }
    }
    var lastCheckedTimestamp: Double {
        didSet { defaults.set(lastCheckedTimestamp, forKey: Key.lastChecked) }
    }

    // MARK: - Derived
    var checkFrequency: CheckFrequency {
        get { CheckFrequency(rawValue: checkFrequencyHours) ?? .fourHours }
        set { checkFrequencyHours = newValue.rawValue }
    }

    var lastCheckedLabel: String {
        guard lastCheckedTimestamp > 0 else { return "Never" }
        let date = Date(timeIntervalSince1970: lastCheckedTimestamp)
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: .now)
    }

    // MARK: - Runtime State
    var isPermissionGranted: Bool = false
    var pendingAlertCount: Int    = 0

    private let service = NotificationService.shared

    // MARK: - Init
    init() {
        checkFrequencyHours   = defaults.object(forKey: Key.checkFrequency) as? Int    ?? NotificationSettings.defaultCheckFrequencyHours
        quietStartHour        = defaults.object(forKey: Key.quietStart)     as? Int    ?? NotificationSettings.defaultQuietStart
        quietEndHour          = defaults.object(forKey: Key.quietEnd)       as? Int    ?? NotificationSettings.defaultQuietEnd
        lowStockAlertsEnabled = defaults.object(forKey: Key.lowStock)       as? Bool   ?? true
        criticalAlertsEnabled = defaults.object(forKey: Key.critical)       as? Bool   ?? true
        lastCheckedTimestamp  = defaults.object(forKey: Key.lastChecked)    as? Double ?? 0
    }

    // MARK: - Permission
    func requestPermission() async {
        isPermissionGranted = await service.requestPermission()
    }

    // MARK: - Refresh Status
    func refreshStatus() async {
        isPermissionGranted = await service.isAuthorized()
        pendingAlertCount   = await service.pendingLowStockCount()

        // A background refresh may have run while we were away — re-sync the
        // "last checked" value so the Status footer is accurate on return.
        let stored = defaults.double(forKey: Key.lastChecked)
        if stored != lastCheckedTimestamp {
            lastCheckedTimestamp = stored
        }
    }

    // MARK: - Low Stock Check
    func triggerLowStockCheck(products: [Product]) async {
        guard isPermissionGranted else { return }
        guard lowStockAlertsEnabled || criticalAlertsEnabled else { return }

        // Filter by status + the user's toggles, then map to Sendable snapshots on
        // the MainActor before handing them to the (off-actor) NotificationService.
        let items: [LowStockItem] = products.compactMap { product in
            switch product.stockStatus {
            case .critical where criticalAlertsEnabled,
                 .low      where lowStockAlertsEnabled:
                return LowStockItem(
                    id: product.id,
                    name: product.name,
                    quantity: product.quantity,
                    unit: product.unit,
                    reorderLevel: product.reorderLevel
                )
            default:
                return nil
            }
        }

        await service.checkAndNotify(
            items:      items,
            quietStart: quietStartHour,
            quietEnd:   quietEndHour
        )

        pendingAlertCount    = await service.pendingLowStockCount()
        lastCheckedTimestamp = Date().timeIntervalSince1970
    }

    // MARK: - Test Notification
    // Calls scheduleTestNotification() directly on the service — bypasses quiet
    // hours so the manual test always fires (and, with the foreground delegate
    // now in place, actually appears on screen while the app is open).
    func sendTestNotification() async {
        guard isPermissionGranted else { return }
        await service.scheduleTestNotification()
    }
}
