import SwiftUI

// MARK: - ContentView
// Root TabView — wires Dashboard and Alerts tabs
// InventoryViewModel is shared so notifications can access product list

struct ContentView: View {

    // Shared across both tabs so NotificationSettingsView
    // can trigger low-stock checks against live inventory
    @State private var inventoryViewModel = InventoryViewModel()

    var body: some View {
        TabView {
            DashboardView(sharedViewModel: inventoryViewModel)
                .tabItem {
                    Label("Inventory", systemImage: "cube.box.fill")
                }

            NotificationSettingsView()
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
