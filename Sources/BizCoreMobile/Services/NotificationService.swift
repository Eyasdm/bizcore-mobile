import Foundation
import UserNotifications

actor NotificationService {

    static let shared = NotificationService()

    private let center = UNUserNotificationCenter.current()
    private let categoryIdentifier = "LOW_STOCK_ALERT"

    // MARK: - Permission

    func requestPermission() async -> Bool {
        do {
            let granted = try await center.requestAuthorization(options: [.alert, .sound, .badge])
            return granted
        } catch {
            return false
        }
    }

    func isAuthorized() async -> Bool {
        let settings = await center.notificationSettings()
        return settings.authorizationStatus == .authorized
    }

    // MARK: - Quiet Hours

    /// Returns true if the current hour falls inside the quiet window.
    /// Handles wrap-around — e.g. quietStart 22, quietEnd 7 correctly covers 22:00–06:59.
    func isInQuietHours(quietStart: Int, quietEnd: Int) -> Bool {
        let hour = Calendar.current.component(.hour, from: Date())
        if quietStart >= quietEnd {
            // Window wraps midnight
            return hour >= quietStart || hour < quietEnd
        } else {
            return hour >= quietStart && hour < quietEnd
        }
    }

    // MARK: - Low Stock Check

    func checkAndNotify(products: [Product], quietStart: Int, quietEnd: Int) async {
        guard !isInQuietHours(quietStart: quietStart, quietEnd: quietEnd) else { return }

        let lowStockProducts = products.filter { $0.quantity <= $0.reorderLevel }

        await cancelLowStockNotifications()

        for product in lowStockProducts {
            await scheduleNotification(for: product)
        }

        await updateBadgeCount(lowStockProducts.count)
    }

    // MARK: - Test Notification
    // Bypasses quiet hours — this is an explicit manual test from the Settings screen.
    // The quietStart:25/quietEnd:25 trick does NOT work: with quietStart >= quietEnd,
    // isInQuietHours takes the wrap-around branch and hour < 25 is always true,
    // so the guard always fires and no notification is ever scheduled.
    // Fix: schedule directly here without going through checkAndNotify.

    func scheduleTestNotification() async {
        let content = UNMutableNotificationContent()
        content.title = "Test Alert — BizCore"
        content.body  = "Low Stock notifications are working correctly."
        content.sound = .default
        content.categoryIdentifier = categoryIdentifier

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)

        let request = UNNotificationRequest(
            identifier: "bizcore-test-\(Int(Date().timeIntervalSince1970))",
            content:    content,
            trigger:    trigger
        )

        try? await center.add(request)
    }

    // MARK: - Cancel

    func cancelLowStockNotifications() async {
        let pending = await center.pendingNotificationRequests()
        let lowStockIDs = pending
            .filter { $0.content.categoryIdentifier == categoryIdentifier }
            .map(\.identifier)

        center.removePendingNotificationRequests(withIdentifiers: lowStockIDs)
        center.removeDeliveredNotifications(withIdentifiers: lowStockIDs)
    }

    func cancelNotification(forProductID productID: String) {
        let identifier = notificationID(for: productID)
        center.removePendingNotificationRequests(withIdentifiers: [identifier])
        center.removeDeliveredNotifications(withIdentifiers: [identifier])
    }

    // MARK: - Pending Count

    func pendingLowStockCount() async -> Int {
        let pending = await center.pendingNotificationRequests()
        return pending.filter { $0.content.categoryIdentifier == categoryIdentifier }.count
    }

    // MARK: - Private

    private func scheduleNotification(for product: Product) async {
        let content = UNMutableNotificationContent()
        content.title = "Low Stock Alert"
        content.body  = "\(product.name) is low — \(product.quantity) \(product.unit) remaining (reorder level: \(product.reorderLevel))"
        content.sound = .default
        content.categoryIdentifier = categoryIdentifier

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)

        let request = UNNotificationRequest(
            identifier: notificationID(for: product.id),
            content:    content,
            trigger:    trigger
        )

        try? await center.add(request)
    }

    private func updateBadgeCount(_ count: Int) async {
        if #available(iOS 16.0, *) {
            try? await center.setBadgeCount(count)
        }
    }

    private func notificationID(for productID: String) -> String {
        "low-stock-\(productID)"
    }
}