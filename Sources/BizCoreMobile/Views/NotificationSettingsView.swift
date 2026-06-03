import SwiftUI

struct NotificationSettingsView: View {
    var body: some View {
        NavigationStack {
            List {
                Section {
                    Label("Alerts coming in Day 5", systemImage: "bell.badge")
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Alerts")
        }
    }
}

#Preview {
    NotificationSettingsView()
}
