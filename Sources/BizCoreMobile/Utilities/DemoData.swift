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
struct DemoData {

    static let products: [Product] = [
        Product(
            id: "demo-001",
            name: "White Cotton Fabric",
            category: "Fabric",
            quantity: 8,
            unit: "meters",
            reorderLevel: 10,
            lastUpdated: .now
        ),
        Product(
            id: "demo-002",
            name: "Black Silk Thread",
            category: "Thread",
            quantity: 3,
            unit: "rolls",
            reorderLevel: 5,
            lastUpdated: .now
        ),
        Product(
            id: "demo-003",
            name: "Gold Buttons 12mm",
            category: "Accessories",
            quantity: 45,
            unit: "pcs",
            reorderLevel: 20,
            lastUpdated: .now
        ),
        Product(
            id: "demo-004",
            name: "Navy Wool Fabric",
            category: "Fabric",
            quantity: 22,
            unit: "meters",
            reorderLevel: 8,
            lastUpdated: .now
        ),
        Product(
            id: "demo-005",
            name: "White Lining Fabric",
            category: "Fabric",
            quantity: 4,
            unit: "meters",
            reorderLevel: 10,
            lastUpdated: .now
        ),
        Product(
            id: "demo-006",
            name: "Invisible Zipper 20cm",
            category: "Accessories",
            quantity: 12,
            unit: "pcs",
            reorderLevel: 15,
            lastUpdated: .now
        ),
        Product(
            id: "demo-007",
            name: "Measuring Tape",
            category: "Tools",
            quantity: 6,
            unit: "pcs",
            reorderLevel: 3,
            lastUpdated: .now
        ),
        Product(
            id: "demo-008",
            name: "Red Chiffon Fabric",
            category: "Fabric",
            quantity: 2,
            unit: "meters",
            reorderLevel: 8,
            lastUpdated: .now
        ),
    ]
}