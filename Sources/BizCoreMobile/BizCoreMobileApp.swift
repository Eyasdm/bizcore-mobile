import SwiftUI
import SwiftData

@main
struct BizCoreMobileApp: App {

    let modelContainer: ModelContainer

    init() {
        do {
            modelContainer = try ModelContainer(
                for: Product.self,
                configurations: ModelConfiguration(isStoredInMemoryOnly: false)
            )
        } catch {
            fatalError("Failed to initialize ModelContainer: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .modelContainer(modelContainer)
        }
    }
}
