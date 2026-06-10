import Foundation
import UserNotifications

// MARK: - LowStockItem
// A Sendable snapshot of just the fields the notification layer needs.
// SwiftData @Model objects are MainActor-bound and NOT Sendable, so passing
// [Product] straight into this actor was a data race waiting to happen. We map
// Product → LowStockItem on the MainActor first, then cross the actor boundary
// with a plain value type. Status is derived from the same shared rule as Product.
struct LowStockItem: Sendable, Identifiable {
    let id: String
    let name: String
    let quantity: Int
    let unit: String
    let reorderLevel: Int

    var stockStatus: StockStatus { .from(quantity: quantity, reorderLevel: reorderLevel) }
}

actor NotificationService {

    static let shared = NotificationService()

    private let center = UNUserNotificationCenter.current()
    private let categoryIdentifier = "LOW_STOCK_ALERT"

    // MARK: - Permission

    func requestPermission() async -> Bool {
        do {
            return try await center.requestAuthorization(options: [.alert, .sound, .badge])
        } catch {
            return false
        }
    }

    func isAuthorized() async -> Bool {
        await center.notificationSettings().authorizationStatus == .authorized
    }

    // MARK: - Quiet Hours

    /// Returns true if the current hour falls inside the quiet window.
    /// Handles wrap-around — e.g. quietStart 22, quietEnd 7 covers 22:00–06:59.
    func isInQuietHours(quietStart: Int, quietEnd: Int) -> Bool {
        let hour = Calendar.current.component(.hour, from: Date())
        if quietStart >= quietEnd {
            return hour >= quietStart || hour < quietEnd   // window wraps midnight
        } else {
            return hour >= quietStart && hour < quietEnd
        }
    }

    // MARK: - Low Stock Check
    // Callers (NotificationViewModel / BackgroundRefresh) already decide WHICH
    // items qualify, using the user's alert-type toggles and each item's status.
    // This method simply schedules for whatever it is handed — there is no second,
    // conflicting threshold here anymore.
    func checkAndNotify(items: [LowStockItem], quietStart: Int, quietEnd: Int) async {
        guard !isInQuietHours(quietStart: quietStart, quietEnd: quietEnd) else { return }

        await cancelLowStockNotifications()

        for item in items {
            await scheduleNotification(for: item)
        }

        await updateBadgeCount(items.count)
    }

    // MARK: - Test Notification
    // Bypasses quiet hours on purpose — this is an explicit manual test from the
    // Settings screen, scheduled directly so it always fires.
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
    // Clears matching alerts from BOTH the pending queue and already-delivered
    // notifications. Gathering IDs only from pending (the old behaviour) left
    // delivered banners stranded in Notification Center after a restock.
    func cancelLowStockNotifications() async {
        let pending = await center.pendingNotificationRequests()
        let pendingIDs = pending
            .filter { $0.content.categoryIdentifier == categoryIdentifier }
            .map(\.identifier)
        center.removePendingNotificationRequests(withIdentifiers: pendingIDs)

        let delivered = await center.deliveredNotifications()
        let deliveredIDs = delivered
            .filter { $0.request.content.categoryIdentifier == categoryIdentifier }
            .map { $0.request.identifier }
        center.removeDeliveredNotifications(withIdentifiers: deliveredIDs)
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

    private func scheduleNotification(for item: LowStockItem) async {
        let content = UNMutableNotificationContent()
        content.title = "Low Stock Alert"
        content.body  = "\(item.name) is low — \(item.quantity) \(item.unit) remaining (reorder level: \(item.reorderLevel))"
        content.sound = .default
        content.categoryIdentifier = categoryIdentifier

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)

        let request = UNNotificationRequest(
            identifier: notificationID(for: item.id),
            content:    content,
            trigger:    trigger
        )

        try? await center.add(request)
    }

    private func updateBadgeCount(_ count: Int) async {
        // iOS 17 target — setBadgeCount (iOS 16+) is always available, so the old
        // `if #available(iOS 16.0, *)` guard was dead code and has been removed.
        try? await center.setBadgeCount(count)
    }

    private func notificationID(for productID: String) -> String {
        "low-stock-\(productID)"
    }
}
