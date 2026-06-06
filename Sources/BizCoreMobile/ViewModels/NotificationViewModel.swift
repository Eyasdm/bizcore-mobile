import SwiftUI
import UserNotifications

// MARK: - NotificationViewModel
@MainActor
@Observable
final class NotificationViewModel {

    // MARK: - Persisted Settings (AppStorage)
    @AppStorage("checkFrequencyHours")   var checkFrequencyHours: Int  = NotificationSettings.defaultCheckFrequencyHours
    @AppStorage("quietStartHour")        var quietStartHour: Int       = NotificationSettings.defaultQuietStart
    @AppStorage("quietEndHour")          var quietEndHour: Int         = NotificationSettings.defaultQuietEnd
    @AppStorage("lowStockAlertsEnabled") var lowStockAlertsEnabled: Bool = true
    @AppStorage("criticalAlertsEnabled") var criticalAlertsEnabled: Bool = true
    @AppStorage("lastCheckedTimestamp")  var lastCheckedTimestamp: Double = 0

    /// Convenience wrapper so views bind to CheckFrequency directly
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

    // MARK: - Permission
    func requestPermission() async {
        isPermissionGranted = await service.requestPermission()
    }

    // MARK: - Refresh Status
    func refreshStatus() async {
        isPermissionGranted = await service.isAuthorized()
        pendingAlertCount   = await service.pendingLowStockCount()
    }

    // MARK: - Low Stock Check
    func triggerLowStockCheck(products: [Product]) async {
        guard isPermissionGranted else { return }
        guard lowStockAlertsEnabled || criticalAlertsEnabled else { return }

        // Filter based on which alerts are enabled
        let toNotify = products.filter { product in
            switch product.stockStatus {
            case .critical: return criticalAlertsEnabled
            case .low:      return lowStockAlertsEnabled
            case .inStock:  return false
            }
        }

        await service.checkAndNotify(
            products:   toNotify,
            quietStart: quietStartHour,
            quietEnd:   quietEndHour
        )

        pendingAlertCount       = await service.pendingLowStockCount()
        lastCheckedTimestamp    = Date().timeIntervalSince1970
    }

    // MARK: - Test Notification
    func sendTestNotification() async {
        guard isPermissionGranted else { return }

        // Create a fake product for the test
        let testProduct = Product(
            id:           "test-notification",
            name:         "Test Product",
            category:     "Demo",
            quantity:     2,
            unit:         "pcs",
            reorderLevel: 5
        )

        await service.checkAndNotify(
            products:   [testProduct],
            quietStart: 25, // impossible hour — bypasses quiet check
            quietEnd:   25
        )
    }
}
