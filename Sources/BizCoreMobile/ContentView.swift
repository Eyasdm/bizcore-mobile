import SwiftUI

struct ContentView: View {

    /// Shared across tabs so the badge reflects live pending count
    /// and DashboardView can trigger checks after a restock.
    @State private var notificationViewModel = NotificationViewModel()

    var body: some View {
        TabView {
            DashboardView(notificationViewModel: notificationViewModel)
                .tabItem {
                    Label("Inventory", systemImage: "cube.box.fill")
                }

            NotificationSettingsView(notificationViewModel: notificationViewModel)
                .tabItem {
                    Label("Alerts", systemImage: "bell.fill")
                }
                .badge(notificationViewModel.pendingAlertCount > 0
                       ? notificationViewModel.pendingAlertCount
                       : 0)
        }
        .tint(.accent)
    }
}

#Preview {
    ContentView()
        .modelContainer(for: Product.self, inMemory: true)
}