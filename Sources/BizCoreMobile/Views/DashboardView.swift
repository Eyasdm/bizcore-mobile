import SwiftUI
import SwiftData

// MARK: - DashboardView
// Main inventory screen
// Features: search, segmented filter, summary chips, ProductRowView list,
//           pull-to-refresh, restock sheet, error alert, notification sync

struct DashboardView: View {

    @Environment(\.modelContext) private var context
    @Query(sort: \Product.name) private var products: [Product]
    @State private var viewModel = InventoryViewModel()

    // Shared NotificationViewModel — updates badge count after restock
    var notificationViewModel: NotificationViewModel

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {

                // Summary header (always visible above list)
                if !products.isEmpty {
                    summaryHeader
                        .padding(.horizontal)
                        .padding(.top, 8)
                        .padding(.bottom, 4)
                }

                // Filter segment
                filterSegment
                    .padding(.horizontal)
                    .padding(.vertical, 8)

                // Main content — grouped is computed once here, used for both
                // the empty-state check and the list render.
                let grouped = viewModel.groupedFiltered(products)

                Group {
                    if viewModel.isRefreshing && products.isEmpty {
                        loadingView
                    } else if grouped.isEmpty {
                        emptyView
                    } else {
                        productList(grouped)
                    }
                }
            }
            .navigationTitle("BizCore")
            .navigationBarTitleDisplayMode(.large)
            .searchable(
                text: $viewModel.searchText,
                prompt: "Search products"
            )
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    refreshButton
                }
                ToolbarItem(placement: .topBarLeading) {
                    demoModeButton
                }
            }
            .refreshable {
                await viewModel.refresh(context: context)
            }
            .task {
                if products.isEmpty {
                    await viewModel.refresh(context: context)
                }
            }
            // Single restock sheet — owned by DashboardView only.
            // ProductDetailView sets selectedProduct + showRestockSheet to trigger it.
            // Having a second .sheet in ProductDetailView causes a SwiftUI conflict.
            .sheet(isPresented: $viewModel.showRestockSheet) {
                if let product = viewModel.selectedProduct {
                    RestockSheet(product: product, viewModel: viewModel, context: context)
                }
            }
            .alert("Error", isPresented: Binding(
                get: { viewModel.errorMessage != nil },
                set: { if !$0 { viewModel.errorMessage = nil } }
            )) {
                Button("OK") { viewModel.errorMessage = nil }
            } message: {
                Text(viewModel.errorMessage ?? "")
            }
            // After restock sheet closes, re-run low-stock check
            // so Alerts tab badge count updates immediately
            .onChange(of: viewModel.showRestockSheet) { _, isShowing in
                if !isShowing {
                    Task {
                        await notificationViewModel.triggerLowStockCheck(products: products)
                        await notificationViewModel.refreshStatus()
                    }
                }
            }
        }
    }

    // MARK: - Summary Header
    private var summaryHeader: some View {
        HStack(spacing: 0) {
            summaryChip(
                count: viewModel.criticalCount(products),
                label: "Critical",
                color: Color(.systemRed)
            )
            Divider().frame(height: 28)
            summaryChip(
                count: viewModel.lowCount(products),
                label: "Low",
                color: Color(.systemOrange)
            )
            Divider().frame(height: 28)
            summaryChip(
                count: products.count,
                label: "Total",
                color: .secondary
            )
        }
        .padding(.vertical, 10)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private func summaryChip(count: Int, label: String, color: Color) -> some View {
        VStack(spacing: 2) {
            Text("\(count)")
                .font(.title3)
                .fontWeight(.bold)
                .foregroundStyle(color)
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(count) \(label) products")
    }

    // MARK: - Filter Segment
    private var filterSegment: some View {
        Picker("Filter", selection: $viewModel.activeFilter) {
            ForEach(StockFilter.allCases) { filter in
                Text(filter.rawValue).tag(filter)
            }
        }
        .pickerStyle(.segmented)
    }

    // MARK: - Product List
    private func productList(_ grouped: [String: [Product]]) -> some View {
        List {
            ForEach(grouped.keys.sorted(), id: \.self) { category in
                Section(header: Text(category).font(.subheadline)) {
                    ForEach(grouped[category] ?? [], id: \.id) { product in
                        NavigationLink {
                            ProductDetailView(product: product, viewModel: viewModel)
                        } label: {
                            ProductRowView(product: product)
                        }
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .animation(.default, value: viewModel.activeFilter)
        .animation(.default, value: viewModel.searchText)
    }

    // MARK: - Loading View
    private var loadingView: some View {
        VStack(spacing: 16) {
            Spacer()
            ProgressView()
                .scaleEffect(1.2)
            Text("Loading inventory…")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Spacer()
        }
    }

    // MARK: - Empty View
    private var emptyView: some View {
        Group {
            if !viewModel.searchText.isEmpty {
                EmptyStateView(
                    symbol: "magnifyingglass",
                    title: "No Results",
                    message: "No products match \"\(viewModel.searchText)\""
                )
            } else if viewModel.activeFilter != .all {
                EmptyStateView(
                    symbol: "checkmark.circle",
                    title: "All Clear",
                    message: "No products in the \(viewModel.activeFilter.rawValue) category"
                )
            } else {
                EmptyStateView(
                    symbol: "cube.box",
                    title: "No Products",
                    message: "Pull down to sync inventory from BizCore",
                    actionLabel: "Sync Now",
                    action: {
                        Task { await viewModel.refresh(context: context) }
                    }
                )
            }
        }
    }

    // MARK: - Toolbar Buttons
    private var refreshButton: some View {
        Button {
            Task { await viewModel.refresh(context: context) }
        } label: {
            if viewModel.isRefreshing {
                ProgressView()
            } else {
                Image(systemName: "arrow.clockwise")
            }
        }
        .accessibilityLabel("Refresh inventory")
        .minTapTarget()
        .disabled(viewModel.isRefreshing)
    }

    private var demoModeButton: some View {
        Button {
            DemoMode.isEnabled.toggle()
            Task { await viewModel.refresh(context: context) }
        } label: {
            Text(DemoMode.isEnabled ? "Demo ON" : "Demo OFF")
                .font(.caption)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(
                    DemoMode.isEnabled
                    ? Color.accentColor.opacity(0.15)
                    : Color(.secondarySystemBackground)
                )
                .foregroundStyle(
                    DemoMode.isEnabled ? Color.accentColor : .secondary
                )
                .clipShape(Capsule())
        }
        .accessibilityLabel(DemoMode.isEnabled ? "Disable demo mode" : "Enable demo mode")
        .minTapTarget()
    }
}

// MARK: - RestockSheet
struct RestockSheet: View {

    let product: Product
    @Bindable var viewModel: InventoryViewModel
    let context: ModelContext
    @Environment(\.dismiss) private var dismiss
    @FocusState private var isTextFieldFocused: Bool

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                // Product info
                VStack(spacing: 6) {
                    Text(product.name)
                        .font(.title3)
                        .fontWeight(.semibold)
                    Text("\(product.quantity) \(product.unit) currently in stock")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding(.top, 8)

                // Input
                VStack(alignment: .leading, spacing: 8) {
                    // "Set stock level to" is accurate — confirmRestock sets quantity = input,
                    // it does NOT add to current stock. Label must match behavior.
                    Text("Set stock level to")
                        .font(.subheadline)
                        .fontWeight(.medium)

                    HStack {
                        TextField("Enter quantity", text: $viewModel.restockQuantityText)
                            .keyboardType(.numberPad)
                            .font(.title2)
                            .fontWeight(.semibold)
                            .focused($isTextFieldFocused)
                            .padding()
                            .background(Color(.secondarySystemBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 10))

                        Text(product.unit)
                            .font(.body)
                            .foregroundStyle(.secondary)
                            .padding(.leading, 4)
                    }
                }
                .padding(.horizontal)

                // Reorder level reminder
                HStack(spacing: 6) {
                    Image(systemName: "info.circle")
                        .foregroundStyle(.secondary)
                    Text("Reorder level: \(product.reorderLevel) \(product.unit)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                // Confirm button
                Button {
                    Task {
                        await viewModel.confirmRestock(product: product, context: context)
                    }
                } label: {
                    Group {
                        if viewModel.isLoading {
                            ProgressView()
                                .tint(.white)
                        } else {
                            Text("Confirm Restock")
                                .fontWeight(.semibold)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(isValidQuantity ? Color.accentColor : Color(.systemGray4))
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .disabled(!isValidQuantity || viewModel.isLoading)
                .padding(.horizontal)
                .minTapTarget()
            }
            .navigationTitle("Restock")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") {
                        viewModel.restockQuantityText = ""
                        dismiss()
                    }
                    .minTapTarget()
                }
            }
            .onAppear {
                isTextFieldFocused = true
            }
        }
        .presentationDetents([.medium])
    }

    private var isValidQuantity: Bool {
        guard let qty = Int(viewModel.restockQuantityText) else { return false }
        return qty > 0
    }
}

// MARK: - ProductDetailView
struct ProductDetailView: View {

    let product: Product
    @Bindable var viewModel: InventoryViewModel
    @Environment(\.modelContext) private var context

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {

                // Status + quantity
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("\(product.quantity)")
                            .font(.system(size: 52, weight: .bold, design: .rounded))
                            .foregroundStyle(quantityColor)
                        Text(product.unit)
                            .font(.title3)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 8) {
                        StatusBadge(status: product.stockStatus)
                        Text("Reorder at \(product.reorderLevel)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding()
                .background(Color(.secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 12))

                // Threshold bar
                thresholdBar

                // Action buttons
                HStack(spacing: 12) {
                    Button {
                        viewModel.selectedProduct = product
                        viewModel.showRestockSheet = true
                        // DashboardView owns the sheet — setting showRestockSheet = true
                        // here triggers DashboardView's .sheet modifier. No second
                        // .sheet modifier on ProductDetailView is needed (or wanted —
                        // two modifiers watching the same bool causes a SwiftUI conflict).
                    } label: {
                        Label("Mark Restocked", systemImage: "plus.circle.fill")
                            .frame(maxWidth: .infinity)
                            .frame(height: 48)
                            .background(Color.accentColor)
                            .foregroundStyle(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                            .fontWeight(.medium)
                    }
                    .minTapTarget()

                    Button {
                        Task {
                            await viewModel.toggleFlag(product: product, context: context)
                        }
                    } label: {
                        Label(
                            product.isFlaggedForReorder ? "Flagged" : "Flag",
                            systemImage: product.isFlaggedForReorder ? "flag.fill" : "flag"
                        )
                        .frame(width: 100, height: 48)
                        .background(
                            product.isFlaggedForReorder
                            ? Color(.systemOrange).opacity(0.15)
                            : Color(.secondarySystemBackground)
                        )
                        .foregroundStyle(
                            product.isFlaggedForReorder
                            ? Color(.systemOrange)
                            : .secondary
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                        .fontWeight(.medium)
                    }
                    .minTapTarget()
                }

                // Meta info
                VStack(alignment: .leading, spacing: 8) {
                    metaRow(label: "Category", value: product.category)
                    metaRow(label: "Last Updated", value: product.lastUpdated.relativeFormatted)
                }
                .padding()
                .background(Color(.secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .padding()
        }
        .navigationTitle(product.name)
        .navigationBarTitleDisplayMode(.large)
        // NOTE: No .sheet here. DashboardView owns the single RestockSheet.
        // A second .sheet modifier on this view watching the same viewModel.showRestockSheet
        // bool would create a SwiftUI sheet conflict when tapping "Mark Restocked".
    }

    // MARK: - Threshold Bar
    private var thresholdBar: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Stock Level")
                .font(.subheadline)
                .fontWeight(.medium)

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color(.systemGray5))
                        .frame(height: 8)

                    RoundedRectangle(cornerRadius: 4)
                        .fill(quantityColor)
                        .frame(width: geo.size.width * fillRatio, height: 8)
                        .animation(.easeOut, value: fillRatio)

                    let markerX = geo.size.width * thresholdRatio
                    Rectangle()
                        .fill(Color(.systemOrange))
                        .frame(width: 2, height: 14)
                        .offset(x: markerX - 1, y: -3)
                }
            }
            .frame(height: 14)

            HStack {
                Text("0")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Spacer()
                Text("Reorder: \(product.reorderLevel)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Spacer()
                Text("Max: \(maxValue)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Stock level: \(product.quantity) \(product.unit). Reorder level: \(product.reorderLevel)")
    }

    private func metaRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .font(.subheadline)
                .fontWeight(.medium)
        }
    }

    private var maxValue: Int { max(product.reorderLevel * 3, product.quantity + 1) }
    private var fillRatio: CGFloat { min(CGFloat(product.quantity) / CGFloat(maxValue), 1.0) }
    private var thresholdRatio: CGFloat { min(CGFloat(product.reorderLevel) / CGFloat(maxValue), 1.0) }

    private var quantityColor: Color {
        switch product.stockStatus {
        case .inStock:  return Color(.systemGreen)
        case .low:      return Color(.systemOrange)
        case .critical: return Color(.systemRed)
        }
    }
}

// MARK: - Previews
#Preview("Dashboard") {
    DashboardView(notificationViewModel: NotificationViewModel())
        .modelContainer(for: Product.self, inMemory: true)
}

#Preview("Product Detail") {
    NavigationStack {
        ProductDetailView(
            product: Product(
                name: "White Cotton Fabric",
                category: "Fabric",
                quantity: 8,
                unit: "meters",
                reorderLevel: 10
            ),
            viewModel: InventoryViewModel()
        )
        .modelContainer(for: Product.self, inMemory: true)
    }
}