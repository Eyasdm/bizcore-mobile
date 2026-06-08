import SwiftUI

// MARK: - ContentView
// Root TabView — wires Dashboard and Alerts tabs
// NotificationViewModel is created once here and shared to both tabs.
// This keeps isPermissionGranted and pendingAlertCount in sync across tabs.

struct ContentView: View {

    // Single shared instance — both tabs read/write the same runtime state.
    @State private var notificationViewModel = NotificationViewModel()

    var body: some View {
        TabView {
            DashboardView(notificationViewModel: notificationViewModel)
                .tabItem {
                    Label("Inventory", systemImage: "cube.box.fill")
                }

            NotificationSettingsView(viewModel: notificationViewModel)
                .tabItem {
                    Label("Alerts", systemImage: "bell.fill")
                }
        }
        .tint(.accentColor)
    }
}

#Preview {
    ContentView()
        .modelContainer(for: Product.self, inMemory: true)
}