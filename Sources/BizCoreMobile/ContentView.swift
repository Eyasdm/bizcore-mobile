import SwiftUI

// MARK: - ContentView
// Root TabView — wires Dashboard and Alerts tabs.
// NotificationViewModel is created once here and shared to both tabs, so
// isPermissionGranted, pendingAlertCount, and lastChecked stay in sync.

struct ContentView: View {

    @Environment(\.scenePhase) private var scenePhase

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
        // Refresh permission + last-checked once on launch...
        .task {
            await notificationViewModel.refreshStatus()
        }
        // ...and every time the app returns to the foreground, so a permission
        // granted in Settings (or a background refresh that ran while away) is
        // reflected immediately instead of only after switching to the Alerts tab.
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                Task { await notificationViewModel.refreshStatus() }
            }
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(for: Product.self, inMemory: true)
}
