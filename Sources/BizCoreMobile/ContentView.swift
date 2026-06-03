import SwiftUI

struct ContentView: View {
    var body: some View {
        TabView {
            DashboardView()
                .tabItem {
                    Label("Inventory", systemImage: "cube.box.fill")
                }

            NotificationSettingsView()
                .tabItem {
                    Label("Alerts", systemImage: "bell.fill")
                }
        }
        .tint(.accent)
    }
}

#Preview {
    ContentView()
        .modelContainer(for: Product.self, inMemory: true)
}
