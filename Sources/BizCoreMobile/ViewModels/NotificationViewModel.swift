import SwiftUI

@MainActor
@Observable
final class NotificationViewModel {

    // MARK: - Persisted Settings
    // Backed by UserDefaults; defaults come from NotificationSettings constants.
    @AppStorage("checkFrequencyHours") var checkFrequencyHours: Int = NotificationSettings.defaultCheckFrequencyHours
    @AppStorage("quietStartHour")      var quietStartHour: Int      = NotificationSettings.defaultQuietStart
    @AppStorage("quietEndHour")        var quietEndHour: Int        = NotificationSettings.defaultQuietEnd

    /// Convenience wrapper so views bind to CheckFrequency directly.
    var checkFrequency: CheckFrequency {
        get { CheckFrequency(rawValue: checkFrequencyHours) ?? .fourHours }
        set { checkFrequencyHours = newValue.rawValue }
    }

    // MARK: - Runtime State
    var isPermissionGranted: Bool = false
    var pendingAlertCount:   Int  = 0

    private let service = NotificationService.shared

    // MARK: - Permission

    func requestPermission() async {
        isPermissionGranted = await service.requestPermission()
    }

    // MARK: - Status

    func refreshStatus() async {
        isPermissionGranted = await service.isAuthorized()
        pendingAlertCount   = await service.pendingLowStockCount()
    }

    // MARK: - Low Stock Check

    func triggerLowStockCheck(products: [Product]) async {
        guard isPermissionGranted else { return }
        await service.checkAndNotify(
            products:   products,
            quietStart: quietStartHour,
            quietEnd:   quietEndHour
        )
        pendingAlertCount = await service.pendingLowStockCount()
    }
}