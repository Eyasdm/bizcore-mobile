import Foundation

// MARK: - Demo Mode Flag
// Persisted via UserDefaults so the toggle survives app restarts.
// Defaults to true on first launch — an assessor cloning the repo gets demo
// data immediately with no code change needed. Toggle is in the app toolbar.
enum DemoMode {
    static var isEnabled: Bool {
        get {
            // First launch: key not yet written → return true (demo ON by default)
            guard UserDefaults.standard.object(forKey: "demoModeEnabled") != nil else {
                return true
            }
            return UserDefaults.standard.bool(forKey: "demoModeEnabled")
        }
        set {
            UserDefaults.standard.set(newValue, forKey: "demoModeEnabled")
        }
    }
}

// MARK: - Demo Products
// Al-Nour Boutique — fictional data for screenshots and assessor demos
//
// Status distribution (reorderLevel thresholds):
//   Critical  → quantity < reorderLevel          (shown in red)
//   Low       → quantity < reorderLevel × 2      (shown in orange)
//   In Stock  → quantity ≥ reorderLevel × 2      (shown in green)
//
// Current distribution: 2 Critical · 2 Low · 4 In Stock
// Summary chips: 2 Critical | 2 Low | 8 Total

struct DemoData {

    static let products: [Product] = [

        // MARK: Fabric
        Product(
            id: "demo-001",
            name: "Red Chiffon Fabric",
            category: "Fabric",
            quantity: 2,             // < reorderLevel 8 → Critical
            unit: "meters",
            reorderLevel: 8,
            lastUpdated: Date(timeIntervalSinceNow: -7_200),   // 2 hours ago
            isFlaggedForReorder: true
        ),
        Product(
            id: "demo-002",
            name: "White Lining Fabric",
            category: "Fabric",
            quantity: 14,            // < reorderLevel 10 × 2 = 20 → Low
            unit: "meters",
            reorderLevel: 10,
            lastUpdated: Date(timeIntervalSinceNow: -86_400)   // 1 day ago
        ),
        Product(
            id: "demo-003",
            name: "White Cotton Fabric",
            category: "Fabric",
            quantity: 35,            // ≥ reorderLevel 10 × 2 = 20 → In Stock
            unit: "meters",
            reorderLevel: 10,
            lastUpdated: Date(timeIntervalSinceNow: -172_800)  // 2 days ago
        ),
        Product(
            id: "demo-004",
            name: "Navy Wool Fabric",
            category: "Fabric",
            quantity: 22,            // ≥ reorderLevel 8 × 2 = 16 → In Stock
            unit: "meters",
            reorderLevel: 8,
            lastUpdated: Date(timeIntervalSinceNow: -259_200)  // 3 days ago
        ),

        // MARK: Thread
        Product(
            id: "demo-005",
            name: "Black Silk Thread",
            category: "Thread",
            quantity: 3,             // < reorderLevel 5 → Critical
            unit: "rolls",
            reorderLevel: 5,
            lastUpdated: Date(timeIntervalSinceNow: -3_600)    // 1 hour ago
        ),

        // MARK: Accessories
        Product(
            id: "demo-006",
            name: "Invisible Zipper 20cm",
            category: "Accessories",
            quantity: 22,            // < reorderLevel 15 × 2 = 30 → Low
            unit: "pcs",
            reorderLevel: 15,
            lastUpdated: Date(timeIntervalSinceNow: -43_200)   // 12 hours ago
        ),
        Product(
            id: "demo-007",
            name: "Gold Buttons 12mm",
            category: "Accessories",
            quantity: 45,            // ≥ reorderLevel 20 × 2 = 40 → In Stock
            unit: "pcs",
            reorderLevel: 20,
            lastUpdated: Date(timeIntervalSinceNow: -345_600)  // 4 days ago
        ),

        // MARK: Tools
        Product(
            id: "demo-008",
            name: "Measuring Tape",
            category: "Tools",
            quantity: 6,             // ≥ reorderLevel 3 × 2 = 6 → In Stock
            unit: "pcs",
            reorderLevel: 3,
            lastUpdated: Date(timeIntervalSinceNow: -604_800)  // 1 week ago
        ),
    ]
}