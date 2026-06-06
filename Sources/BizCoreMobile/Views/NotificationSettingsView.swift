import SwiftUI
import SwiftData

// MARK: - NotificationSettingsView
// Full notification settings screen — replaces Day 1 placeholder
// Features: permission toggle, low/critical toggles, frequency picker,
//           quiet hours, test notification button, pending alert count

struct NotificationSettingsView: View {

    @Environment(\.modelContext) private var context
    @Query(sort: \Product.name) private var products: [Product]
    @State private var viewModel = NotificationViewModel()
    @State private var showPermissionAlert = false

    var body: some View {
        NavigationStack {
            List {

                // MARK: Permission Section
                Section {
                    permissionRow
                } header: {
                    Text("Notification Access")
                } footer: {
                    Text("Required to receive low-stock alerts on your device.")
                }

                // MARK: Alert Types Section
                if viewModel.isPermissionGranted {
                    Section {
                        Toggle(isOn: Binding(
                            get: { viewModel.lowStockAlertsEnabled },
                            set: { viewModel.lowStockAlertsEnabled = $0 }
                        )) {
                            Label {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Low Stock Alerts")
                                        .font(.body)
                                    Text("Products below reorder level × 2")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            } icon: {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundStyle(Color(.systemOrange))
                            }
                        }
                        .minTapTarget()

                        Toggle(isOn: Binding(
                            get: { viewModel.criticalAlertsEnabled },
                            set: { viewModel.criticalAlertsEnabled = $0 }
                        )) {
                            Label {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Critical Alerts")
                                        .font(.body)
                                    Text("Products below reorder level")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            } icon: {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundStyle(Color(.systemRed))
                            }
                        }
                        .minTapTarget()

                    } header: {
                        Text("Alert Types")
                    }

                    // MARK: Frequency Section
                    Section {
                        Picker("Check Frequency", selection: $viewModel.checkFrequency) {
                            ForEach(CheckFrequency.allCases) { freq in
                                Text(freq.label).tag(freq)
                            }
                        }
                        .pickerStyle(.navigationLink)
                        .minTapTarget()
                    } header: {
                        Text("Check Frequency")
                    } footer: {
                        Text("How often the app checks for low-stock products in the background.")
                    }

                    // MARK: Quiet Hours Section
                    Section {
                        HStack {
                            Label("Start", systemImage: "moon.fill")
                                .foregroundStyle(.primary)
                            Spacer()
                            Picker("Quiet Start", selection: $viewModel.quietStartHour) {
                                ForEach(0..<24, id: \.self) { hour in
                                    Text(hourLabel(hour)).tag(hour)
                                }
                            }
                            .pickerStyle(.menu)
                            .minTapTarget()
                        }

                        HStack {
                            Label("End", systemImage: "sun.rise.fill")
                                .foregroundStyle(.primary)
                            Spacer()
                            Picker("Quiet End", selection: $viewModel.quietEndHour) {
                                ForEach(0..<24, id: \.self) { hour in
                                    Text(hourLabel(hour)).tag(hour)
                                }
                            }
                            .pickerStyle(.menu)
                            .minTapTarget()
                        }
                    } header: {
                        Text("Quiet Hours")
                    } footer: {
                        Text("No alerts will be sent between \(hourLabel(viewModel.quietStartHour)) and \(hourLabel(viewModel.quietEndHour)).")
                    }

                    // MARK: Status Section
                    Section {
                        HStack {
                            Label("Pending Alerts", systemImage: "bell.badge")
                            Spacer()
                            Text("\(viewModel.pendingAlertCount)")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundStyle(
                                    viewModel.pendingAlertCount > 0
                                    ? Color(.systemOrange)
                                    : .secondary
                                )
                        }

                        // Check now button
                        Button {
                            Task {
                                await viewModel.triggerLowStockCheck(products: products)
                            }
                        } label: {
                            Label("Check Inventory Now", systemImage: "arrow.clockwise")
                                .foregroundStyle(Color.accentColor)
                        }
                        .minTapTarget()

                        // Test notification button
                        Button {
                            Task {
                                await viewModel.sendTestNotification()
                            }
                        } label: {
                            Label("Send Test Notification", systemImage: "paperplane.fill")
                                .foregroundStyle(Color.accentColor)
                        }
                        .minTapTarget()

                    } header: {
                        Text("Status")
                    } footer: {
                        Text("Last checked: \(viewModel.lastCheckedLabel)")
                    }
                }

                // MARK: About Section
                Section {
                    HStack(spacing: 12) {
                        Image(systemName: "info.circle")
                            .foregroundStyle(.secondary)
                        Text("Notifications are delivered locally — no internet connection required.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 4)
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Alerts")
            .navigationBarTitleDisplayMode(.large)
            .task {
                await viewModel.refreshStatus()
            }
            .alert("Enable Notifications", isPresented: $showPermissionAlert) {
                Button("Open Settings") {
                    if let url = URL(string: UIKit.UIApplication.openSettingsURLString) {
                        UIKit.UIApplication.shared.open(url)
                    }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Please enable notifications for BizCore in Settings to receive low-stock alerts.")
            }
        }
    }

    // MARK: - Permission Row
    private var permissionRow: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(viewModel.isPermissionGranted
                          ? Color(.systemGreen).opacity(0.15)
                          : Color(.systemRed).opacity(0.15))
                    .frame(width: 40, height: 40)
                Image(systemName: viewModel.isPermissionGranted
                      ? "bell.fill"
                      : "bell.slash.fill")
                    .foregroundStyle(viewModel.isPermissionGranted
                                     ? Color(.systemGreen)
                                     : Color(.systemRed))
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(viewModel.isPermissionGranted ? "Notifications Enabled" : "Notifications Disabled")
                    .font(.body)
                    .fontWeight(.medium)
                Text(viewModel.isPermissionGranted
                     ? "BizCore can send low-stock alerts"
                     : "Tap to enable in Settings")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if !viewModel.isPermissionGranted {
                Button("Enable") {
                    Task {
                        await viewModel.requestPermission()
                        if !viewModel.isPermissionGranted {
                            showPermissionAlert = true
                        }
                    }
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                .minTapTarget()
            }
        }
        .padding(.vertical, 4)
    }

    // MARK: - Hour Label Helper
    private func hourLabel(_ hour: Int) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        var components = DateComponents()
        components.hour   = hour
        components.minute = 0
        guard let date = Calendar.current.date(from: components) else {
            return "\(hour):00"
        }
        return formatter.string(from: date)
    }
}

// MARK: - Preview
#Preview {
    NotificationSettingsView()
        .modelContainer(for: Product.self, inMemory: true)
}
