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

        if !searchText.isEmpty {
            result = result.filter {
                $0.name.localizedCaseInsensitiveContains(searchText) ||
                $0.category.localizedCaseInsensitiveContains(searchText)
            }
        }

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

    // MARK: - Grouped (for dashboard list and empty-state check)
    // Single entry point so the empty check and the list render off the same call.
    func groupedFiltered(_ products: [Product]) -> [String: [Product]] {
        Dictionary(grouping: filtered(products), by: { $0.category })
    }

    // MARK: - Summary Counts
    func criticalCount(_ products: [Product]) -> Int {
        products.filter { $0.stockStatus == .critical }.count
    }

    func lowCount(_ products: [Product]) -> Int {
        products.filter { $0.stockStatus == .low }.count
    }

    // MARK: - Refresh from Supabase
    func refresh(context: ModelContext) async {
        if DemoMode.isEnabled {
            await loadDemoData(context: context)
            return
        }

        isRefreshing = true
        errorMessage = nil

        do {
            let remoteProducts = try await SupabaseService.shared.fetchProducts()

            // Upsert: fetch existing records once, then update-or-insert per remote product.
            // Without this, every refresh call would append duplicate rows because SwiftData's
            // internal PersistentIdentifier differs from our custom id: String field.
            let existing = try context.fetch(FetchDescriptor<Product>())
            let existingByID = Dictionary(uniqueKeysWithValues: existing.map { ($0.id, $0) })
            let isoFormatter = ISO8601DateFormatter()

            for remote in remoteProducts {
                if let product = existingByID[remote.id] {
                    // Record exists — update fields in place, no new row
                    product.quantity            = remote.quantity
                    product.lastUpdated         = isoFormatter.date(from: remote.updated_at ?? "") ?? .now
                    product.isFlaggedForReorder = remote.flagged_for_reorder ?? false
                } else {
                    // New product — insert
                    context.insert(remote.toProduct())
                }
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

        // Optimistic local update
        product.quantity = newQty
        product.lastUpdated = .now
        product.isFlaggedForReorder = false

        do {
            try context.save()

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
        let descriptor = FetchDescriptor<Product>()
        if let existing = try? context.fetch(descriptor) {
            for product in existing {
                context.delete(product)
            }
        }

        for product in DemoData.products {
            context.insert(product)
        }

        try? context.save()
        isRefreshing = false
    }
}