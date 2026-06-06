import SwiftUI
import SwiftData

// MARK: - NotificationSettingsView
// Full Alerts tab — permission gate, status summary, frequency picker,
// quiet hours picker, and a manual low-stock check trigger.
// Receives NotificationViewModel from ContentView so the tab badge stays in sync.

struct NotificationSettingsView: View {

    @Query(sort: \Product.name) private var products: [Product]
    @Bindable var notificationViewModel: NotificationViewModel

    var body: some View {
        NavigationStack {
            List {

                // ── 1. Permission Banner ──────────────────────────────────
                permissionSection

                // ── 2. Status Summary ─────────────────────────────────────
                if notificationViewModel.isPermissionGranted {
                    statusSection
                }

                // ── 3. Alert Frequency ────────────────────────────────────
                if notificationViewModel.isPermissionGranted {
                    frequencySection
                }

                // ── 4. Quiet Hours ────────────────────────────────────────
                if notificationViewModel.isPermissionGranted {
                    quietHoursSection
                }

                // ── 5. Manual Check ───────────────────────────────────────
                if notificationViewModel.isPermissionGranted {
                    manualCheckSection
                }

            }
            .listStyle(.insetGrouped)
            .navigationTitle("Alerts")
            .navigationBarTitleDisplayMode(.large)
            .task {
                await notificationViewModel.refreshStatus()
            }
        }
    }

    // MARK: - Permission Section

    private var permissionSection: some View {
        Section {
            if notificationViewModel.isPermissionGranted {
                HStack(spacing: 12) {
                    Image(systemName: "bell.badge.fill")
                        .font(.title2)
                        .foregroundStyle(Color(.systemGreen))
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Notifications Enabled")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        Text("BizCore can send low-stock alerts to this device.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.vertical, 4)
            } else {
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 12) {
                        Image(systemName: "bell.slash.fill")
                            .font(.title2)
                            .foregroundStyle(.secondary)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Notifications Off")
                                .font(.subheadline)
                                .fontWeight(.medium)
                            Text("Enable alerts to get notified when stock runs low.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }

                    Button {
                        Task { await notificationViewModel.requestPermission() }
                    } label: {
                        Text("Enable Notifications")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .frame(maxWidth: .infinity)
                            .frame(height: 40)
                            .background(Color.accentColor)
                            .foregroundStyle(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                    .buttonStyle(.plain)

                    Button {
                        if let url = URL(string: UIApplication.openSettingsURLString) {
                            UIApplication.shared.open(url)
                        }
                    } label: {
                        Text("Open System Settings")
                            .font(.caption)
                            .frame(maxWidth: .infinity)
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.vertical, 6)
            }
        } header: {
            Text("Permission")
        }
    }

    // MARK: - Status Section

    private var statusSection: some View {
        Section {
            HStack {
                Label("Pending Low-Stock Alerts", systemImage: "tray.and.arrow.down")
                Spacer()
                if notificationViewModel.pendingAlertCount == 0 {
                    Text("None")
                        .foregroundStyle(.secondary)
                        .font(.subheadline)
                } else {
                    Text("\(notificationViewModel.pendingAlertCount)")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundStyle(Color(.systemOrange))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 3)
                        .background(Color(.systemOrange).opacity(0.12))
                        .clipShape(Capsule())
                }
            }
        } header: {
            Text("Status")
        } footer: {
            Text("Pending alerts scheduled but not yet delivered.")
        }
    }

    // MARK: - Frequency Section

    private var frequencySection: some View {
        Section {
            Picker("Check Frequency", selection: $notificationViewModel.checkFrequency) {
                ForEach(CheckFrequency.allCases) { freq in
                    Text(freq.label).tag(freq)
                }
            }
            .pickerStyle(.menu)
        } header: {
            Text("Alert Frequency")
        } footer: {
            Text("How often BizCore checks inventory and may send alerts.")
        }
    }

    // MARK: - Quiet Hours Section

    private var quietHoursSection: some View {
        Section {
            HStack {
                Text("Do Not Disturb From")
                Spacer()
                hourPicker(selection: $notificationViewModel.quietStartHour)
            }
            HStack {
                Text("Until")
                Spacer()
                hourPicker(selection: $notificationViewModel.quietEndHour)
            }
        } header: {
            Text("Quiet Hours")
        } footer: {
            Text("No alerts will be sent during this window. Wrap-around (e.g. 10 PM – 7 AM) is supported.")
        }
    }

    private func hourPicker(selection: Binding<Int>) -> some View {
        Picker("Hour", selection: selection) {
            ForEach(0..<24, id: \.self) { hour in
                Text(hourLabel(hour)).tag(hour)
            }
        }
        .pickerStyle(.menu)
        .labelsHidden()
    }

    private func hourLabel(_ hour: Int) -> String {
        var comps = DateComponents()
        comps.hour = hour
        comps.minute = 0
        if let date = Calendar.current.date(from: comps) {
            let fmt = DateFormatter()
            fmt.dateFormat = "h a"
            return fmt.string(from: date)
        }
        return "\(hour):00"
    }

    // MARK: - Manual Check Section

    private var manualCheckSection: some View {
        Section {
            Button {
                Task {
                    await notificationViewModel.triggerLowStockCheck(products: products)
                    await notificationViewModel.refreshStatus()
                }
            } label: {
                Label("Check Now", systemImage: "arrow.clockwise.circle.fill")
                    .fontWeight(.medium)
                    .foregroundStyle(Color.accentColor)
            }
        } header: {
            Text("Manual Check")
        } footer: {
            Text("Instantly scan inventory and schedule alerts for low-stock products (quiet hours still apply).")
        }
    }
}

// MARK: - Preview

#Preview {
    NotificationSettingsView(notificationViewModel: NotificationViewModel())
        .modelContainer(for: Product.self, inMemory: true)
}