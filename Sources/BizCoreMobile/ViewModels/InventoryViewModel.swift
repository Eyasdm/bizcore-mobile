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

            // Upsert: fetch existing records once, then update-or-insert per remote
            // product. Without this, every refresh would append duplicate rows
            // because SwiftData's PersistentIdentifier differs from our custom
            // id: String field.
            let existing = try context.fetch(FetchDescriptor<Product>())
            let existingByID = Dictionary(uniqueKeysWithValues: existing.map { ($0.id, $0) })
            let isoFormatter = ISO8601DateFormatter()

            for remote in remoteProducts {
                if let product = existingByID[remote.id] {
                    product.quantity            = remote.quantity
                    product.lastUpdated         = isoFormatter.date(from: remote.updated_at ?? "") ?? .now
                    product.isFlaggedForReorder = remote.flagged_for_reorder ?? false
                } else {
                    context.insert(remote.toProduct())
                }
            }

            // Reconcile deletions: drop local rows that no longer exist remotely,
            // so a product removed in BizCore Desktop also disappears here instead
            // of lingering as a stale cache entry forever.
            let remoteIDs = Set(remoteProducts.map(\.id))
            for product in existing where !remoteIDs.contains(product.id) {
                context.delete(product)
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

        // Snapshot for rollback. The previous version kept the optimistic local
        // write even when the remote PATCH failed, leaving local and server stock
        // permanently out of sync. Now a failed write reverts the local change.
        let previousQty     = product.quantity
        let previousUpdated = product.lastUpdated
        let previousFlag    = product.isFlaggedForReorder

        product.quantity            = newQty
        product.lastUpdated         = .now
        product.isFlaggedForReorder = false

        do {
            try context.save()

            if !DemoMode.isEnabled {
                try await SupabaseService.shared.updateQuantity(
                    productID: product.id,
                    newQuantity: newQty
                )
            }

            // Success — close and reset.
            isLoading           = false
            showRestockSheet    = false
            restockQuantityText = ""
            selectedProduct     = nil
        } catch {
            // Roll back so the cached value matches the server.
            product.quantity            = previousQty
            product.lastUpdated         = previousUpdated
            product.isFlaggedForReorder = previousFlag
            try? context.save()

            errorMessage = error.localizedDescription
            isLoading    = false
            // Sheet stays open so the user can retry.
        }
    }

    // MARK: - Flag for Reorder
    func toggleFlag(product: Product, context: ModelContext) async {
        let previous = product.isFlaggedForReorder
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
            // Revert the flag if the server update fails.
            product.isFlaggedForReorder = previous
            try? context.save()
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
