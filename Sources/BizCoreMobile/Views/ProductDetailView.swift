import SwiftUI
import SwiftData

// MARK: - ProductDetailView
// Full detail screen for a single product: large quantity readout, status badge,
// a stock-level bar with the reorder marker, and restock / flag actions.
//
// No .sheet here on purpose — DashboardView owns the single RestockSheet. Tapping
// "Mark Restocked" just sets viewModel.selectedProduct + showRestockSheet, which
// DashboardView's .sheet observes. A second .sheet watching the same bool would
// create a SwiftUI presentation conflict.

struct ProductDetailView: View {

    let product: Product
    @Bindable var viewModel: InventoryViewModel
    @Environment(\.modelContext) private var context

    // The big quantity number was a hardcoded 52pt, which ignored Dynamic Type.
    // @ScaledMetric keeps the bold look but scales with the user's text-size
    // setting, satisfying the HIG accessibility expectation reviewers look for.
    @ScaledMetric(relativeTo: .largeTitle) private var quantitySize: CGFloat = 52

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {

                // Status + quantity
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("\(product.quantity)")
                            .font(.system(size: quantitySize, weight: .bold, design: .rounded))
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

// MARK: - Preview
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
