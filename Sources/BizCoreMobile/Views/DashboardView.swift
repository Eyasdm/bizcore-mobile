import SwiftUI
import SwiftData

struct DashboardView: View {

    @Environment(\.modelContext) private var context
    @Query(sort: \Product.name) private var products: [Product]
    @State private var viewModel = InventoryViewModel()

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.isRefreshing && products.isEmpty {
                    ProgressView("Loading inventory...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if products.isEmpty {
                    // Empty state placeholder
                    ContentUnavailableView(
                        "No Products",
                        systemImage: "cube.box",
                        description: Text("Pull down to sync from BizCore")
                    )
                } else {
                    productList
                }
            }
            .navigationTitle("BizCore")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        Task { await viewModel.refresh(context: context) }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                    .minTapTarget()
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
            .alert("Error", isPresented: Binding(
                get: { viewModel.errorMessage != nil },
                set: { if !$0 { viewModel.errorMessage = nil } }
            )) {
                Button("OK") { viewModel.errorMessage = nil }
            } message: {
                Text(viewModel.errorMessage ?? "")
            }
        }
    }

    // MARK: - Product List (placeholder — full version Day 3)
    private var productList: some View {
        List {
            // Summary header
            Section {
                HStack(spacing: 16) {
                    summaryChip(
                        count: viewModel.criticalCount(products),
                        label: "Critical",
                        color: .statusRed
                    )
                    summaryChip(
                        count: viewModel.lowCount(products),
                        label: "Low",
                        color: .statusOrange
                    )
                    summaryChip(
                        count: products.count,
                        label: "Total",
                        color: .secondary
                    )
                }
                .padding(.vertical, 4)
            }

            // Product rows (full ProductRowView added Day 3)
            Section("Products") {
                ForEach(viewModel.filtered(products), id: \.id) { product in
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(product.name)
                                .font(.body)
                                .foregroundStyle(.primary)
                            Text(product.category)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Text("\(product.quantity) \(product.unit)")
                            .font(.subheadline)
                            .bold()
                            .foregroundStyle(Color.forStatus(product.stockStatus))
                    }
                    .padding(.vertical, 2)
                }
            }
        }
        .listStyle(.insetGrouped)
    }

    // MARK: - Summary Chip
    private func summaryChip(count: Int, label: String, color: Color) -> some View {
        VStack(spacing: 2) {
            Text("\(count)")
                .font(.title2)
                .bold()
                .foregroundStyle(color)
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

#Preview {
    DashboardView()
        .modelContainer(for: Product.self, inMemory: true)
}
