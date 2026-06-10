import SwiftUI
import SwiftData
import UserNotifications

@main
struct BizCoreMobileApp: App {

    @Environment(\.scenePhase) private var scenePhase

    let modelContainer: ModelContainer

    // Held strongly here because UNUserNotificationCenter.delegate is weak.
    // If this were a local in init(), it would deallocate and banners would
    // stop showing while the app is in the foreground.
    private let notificationDelegate = NotificationDelegate()

    init() {
        do {
            modelContainer = try ModelContainer(
                for: Product.self,
                configurations: ModelConfiguration(isStoredInMemoryOnly: false)
            )
        } catch {
            fatalError("Failed to initialize ModelContainer: \(error)")
        }

        // Show alert banners even while the app is open (see NotificationDelegate).
        UNUserNotificationCenter.current().delegate = notificationDelegate

        // Background refresh must be REGISTERED before launch finishes. App.init()
        // is the earliest hook in the SwiftUI lifecycle and runs before any scene.
        BackgroundRefresh.register()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .modelContainer(modelContainer)
        }
        .onChange(of: scenePhase) { _, phase in
            // Queue the next background inventory check whenever we leave the app.
            if phase == .background {
                BackgroundRefresh.schedule()
            }
        }
    }
}

// MARK: - Notification Delegate
// Since iOS 14, a foreground app suppresses notification banners unless its
// delegate explicitly opts in via willPresent. Without this, "Send Test
// Notification" and restock-triggered alerts would fire silently with nothing
// on screen — the exact reason the feature looked broken in a live demo.
final class NotificationDelegate: NSObject, UNUserNotificationCenterDelegate {
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .sound, .badge]
    }
}
