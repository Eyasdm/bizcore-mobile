import SwiftUI

@MainActor
@Observable
final class NotificationViewModel {

    // MARK: - State
    var isPermissionGranted: Bool = false
    var pendingAlertCount: Int = 0

    private let service = NotificationService.shared

    // MARK: - Permission

    func requestPermission() async {
        isPermissionGranted = await service.requestPermission()
    }

    // MARK: - Status

    func refreshStatus() async {
        isPermissionGranted = await service.isAuthorized()
        pendingAlertCount = await service.pendingLowStockCount()
    }

    // MARK: - Low Stock Check

    func triggerLowStockCheck(products: [Product]) async {
        guard isPermissionGranted else { return }
        await service.checkAndNotify(products: products)
        pendingAlertCount = await service.pendingLowStockCount()
    }
}
