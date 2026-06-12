import SwiftUI
import SwiftData

// MARK: - DashboardView
// Main inventory screen
// Features: search, segmented filter, summary chips, ProductRowView list,
//           pull-to-refresh, restock sheet, error alert, notification sync
//
// RestockSheet and ProductDetailView now live in their own files
// (RestockSheet.swift, ProductDetailView.swift). This file previously held all
// three structs at 554 lines; splitting keeps each screen independently readable.

@MainActor struct DashboardView: View {

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
                // Keep permission state current so the post-restock check below
                // isn't a silent no-op when the user granted access on the Alerts tab.
                await notificationViewModel.refreshStatus()
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
            // After the restock sheet closes — by Confirm, Cancel, OR an interactive
            // swipe-down — re-run the low-stock check so the Alerts badge updates,
            // and clear the sheet's scratch state. Resetting here (not only in the
            // Cancel button) fixes stale restockQuantityText / selectedProduct after
            // a swipe dismiss.
            .onChange(of: viewModel.showRestockSheet) { _, isShowing in
                if !isShowing {
                    viewModel.restockQuantityText = ""
                    viewModel.selectedProduct = nil
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

// MARK: - Preview
#Preview("Dashboard") {
    DashboardView(notificationViewModel: NotificationViewModel())
        .modelContainer(for: Product.self, inMemory: true)
}