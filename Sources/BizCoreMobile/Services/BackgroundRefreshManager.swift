import Foundation
import BackgroundTasks

// MARK: - BackgroundRefresh
// Periodic, OS-scheduled inventory check via BGAppRefreshTask. This is what makes
// the Check Frequency setting real instead of decorative: it reschedules itself
// using the user's chosen interval and fires low-stock notifications without the
// app being open.
//
// Honest limits (documented in the README too): iOS decides the actual run time
// based on usage, battery, and network — there is no guaranteed delivery moment.
// True "the instant stock changes on the server" delivery would need a server
// push path (Supabase Edge Function → APNs); that is the stated roadmap, not this.
enum BackgroundRefresh {

    /// Must match BGTaskSchedulerPermittedIdentifiers in Info.plist exactly,
    /// or BGTaskScheduler.register traps at launch.
    static let taskIdentifier = "com.bizcore.refresh"

    // MARK: - Registration (call once, before launch finishes)
    static func register() {
        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: taskIdentifier,
            using: nil
        ) { task in
            // Safe: the only identifier we register is the app-refresh task above.
            handle(task as! BGAppRefreshTask)
        }
    }

    // MARK: - Scheduling
    static func schedule() {
        let hours = UserDefaults.standard.object(forKey: "checkFrequencyHours") as? Int
            ?? NotificationSettings.defaultCheckFrequencyHours

        let request = BGAppRefreshTaskRequest(identifier: taskIdentifier)
        request.earliestBeginDate = Date(timeIntervalSinceNow: Double(hours) * 3600)

        do {
            try BGTaskScheduler.shared.submit(request)
        } catch {
            // The simulator usually refuses real scheduling — that is expected and
            // harmless. On device this only fails if background refresh is disabled.
            print("BackgroundRefresh: could not schedule — \(error.localizedDescription)")
        }
    }

    // MARK: - Handler
    private static func handle(_ task: BGAppRefreshTask) {
        // Re-arm the chain first so a cut-short run still queues the next check.
        schedule()

        let work = Task {
            await runLowStockCheck()
            task.setTaskCompleted(success: true)
        }

        // If the OS reclaims time, stop our work; network awaits honour cancellation.
        task.expirationHandler = {
            work.cancel()
        }
    }

    // MARK: - The actual check
    private static func runLowStockCheck() async {
        let defaults = UserDefaults.standard

        let lowEnabled      = defaults.object(forKey: "lowStockAlertsEnabled") as? Bool ?? true
        let criticalEnabled = defaults.object(forKey: "criticalAlertsEnabled") as? Bool ?? true
        guard lowEnabled || criticalEnabled else { return }

        let quietStart = defaults.object(forKey: "quietStartHour") as? Int ?? NotificationSettings.defaultQuietStart
        let quietEnd   = defaults.object(forKey: "quietEndHour")   as? Int ?? NotificationSettings.defaultQuietEnd

        // Source of truth: demo data when demo mode is on (there is no backend to
        // poll), live Supabase otherwise. Same code path either way, so the feature
        // is demonstrable in demo mode and real in live mode.
        let allItems: [LowStockItem]
        if DemoMode.isEnabled {
            allItems = await MainActor.run {
                DemoData.products.map {
                    LowStockItem(id: $0.id, name: $0.name, quantity: $0.quantity,
                                 unit: $0.unit, reorderLevel: $0.reorderLevel)
                }
            }
        } else {
            guard let remote = try? await SupabaseService.shared.fetchProducts() else { return }
            allItems = remote.map {
                LowStockItem(id: $0.id, name: $0.name, quantity: $0.quantity,
                             unit: $0.unit, reorderLevel: $0.reorder_level)
            }
        }

        // Same status-based filter the foreground path uses (single threshold rule).
        let toNotify = allItems.filter { item in
            switch item.stockStatus {
            case .critical: return criticalEnabled
            case .low:      return lowEnabled
            case .inStock:  return false
            }
        }

        await NotificationService.shared.checkAndNotify(
            items: toNotify,
            quietStart: quietStart,
            quietEnd: quietEnd
        )

        defaults.set(Date().timeIntervalSince1970, forKey: "lastCheckedTimestamp")
    }
}
