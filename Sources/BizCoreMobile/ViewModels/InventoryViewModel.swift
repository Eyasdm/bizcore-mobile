import SwiftUI
import SwiftData

// MARK: - Filter Enum
enum StockFilter: String, CaseIterable, Identifiable {
    case all      = "All"
    case low      = "Low Stock"
    case critical = "Critical"

    var id: String { rawValue }
}

// MARK: - InventoryViewModel
@MainActor
@Observable
final class InventoryViewModel {

    // MARK: - State
    var searchText: String = ""
    var activeFilter: StockFilter = .all
    var isLoading: Bool = false
    var isRefreshing: Bool = false
    var errorMessage: String? = nil
    var showRestockSheet: Bool = false
    var selectedProduct: Product? = nil
    var restockQuantityText: String = ""

    // MARK: - Filter Products
    // Called from DashboardView with the full @Query result
    func filtered(_ products: [Product]) -> [Product] {
        var result = products

        // Apply search
        if !searchText.isEmpty {
            result = result.filter {
                $0.name.localizedCaseInsensitiveContains(searchText) ||
                $0.category.localizedCaseInsensitiveContains(searchText)
            }
        }

        // Apply status filter
        switch activeFilter {
        case .all:
            break
        case .low:
            result = result.filter { $0.stockStatus == .low || $0.stockStatus == .critical }
        case .critical:
            result = result.filter { $0.stockStatus == .critical }
        }

        return result
    }

    // MARK: - Summary Counts (for dashboard header)
    func criticalCount(_ products: [Product]) -> Int {
        products.filter { $0.stockStatus == .critical }.count
    }

    func lowCount(_ products: [Product]) -> Int {
        products.filter { $0.stockStatus == .low }.count
    }

    // MARK: - Refresh from Supabase
    func refresh(context: ModelContext) async {
        // In demo mode — skip network call and just use local data
        if DemoMode.isEnabled {
            await loadDemoData(context: context)
            return
        }

        isRefreshing = true
        errorMessage = nil

        do {
            let remoteProducts = try await SupabaseService.shared.fetchProducts()

            // Upsert into SwiftData
            for remote in remoteProducts {
                let product = remote.toProduct()
                context.insert(product)
            }

            try context.save()
        } catch {
            errorMessage = error.localizedDescription
        }

        isRefreshing = false
    }

    // MARK: - Restock Action
    func confirmRestock(product: Product, context: ModelContext) async {
        guard let newQty = Int(restockQuantityText), newQty > 0 else {
            errorMessage = "Please enter a valid quantity."
            return
        }

        isLoading = true
        errorMessage = nil

        // Update locally first (optimistic update)
        product.quantity = newQty
        product.lastUpdated = .now
        product.isFlaggedForReorder = false

        do {
            try context.save()

            // Sync to Supabase if not in demo mode
            if !DemoMode.isEnabled {
                try await SupabaseService.shared.updateQuantity(
                    productID: product.id,
                    newQuantity: newQty
                )
            }
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
        showRestockSheet = false
        restockQuantityText = ""
        selectedProduct = nil
    }

    // MARK: - Flag for Reorder
    func toggleFlag(product: Product, context: ModelContext) async {
        product.isFlaggedForReorder.toggle()

        do {
            try context.save()

            if !DemoMode.isEnabled {
                try await SupabaseService.shared.updateFlag(
                    productID: product.id,
                    flagged: product.isFlaggedForReorder
                )
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Demo Data Loader
    private func loadDemoData(context: ModelContext) async {
        // Clear existing products first
        let descriptor = FetchDescriptor<Product>()
        if let existing = try? context.fetch(descriptor) {
            for product in existing {
                context.delete(product)
            }
        }

        // Insert demo products
        for product in DemoData.products {
            context.insert(product)
        }

        try? context.save()
        isRefreshing = false
    }
}
