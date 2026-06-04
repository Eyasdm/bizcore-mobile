import SwiftUI

// MARK: - ProductRowView
// Reusable row for the dashboard inventory list
// Shows: product name, category, quantity + unit, status badge, flag indicator

struct ProductRowView: View {

    let product: Product

    var body: some View {
        HStack(spacing: 12) {

            // Left: status color stripe
            RoundedRectangle(cornerRadius: 3)
                .fill(stripeColor)
                .frame(width: 4)
                .padding(.vertical, 2)

            // Center: name + category
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(product.name)
                        .font(.body)
                        .fontWeight(.medium)
                        .foregroundStyle(.primary)
                        .lineLimit(1)

                    // Flag indicator
                    if product.isFlaggedForReorder {
                        Image(systemName: "flag.fill")
                            .font(.caption2)
                            .foregroundStyle(.orange)
                    }
                }

                Text(product.category)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            // Right: quantity + badge
            VStack(alignment: .trailing, spacing: 4) {
                Text("\(product.quantity) \(product.unit)")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(quantityColor)

                StatusBadge(status: product.stockStatus)
            }
        }
        .padding(.vertical, 6)
        .contentShape(Rectangle()) // full row is tappable
    }

    // MARK: - Color Helpers
    private var stripeColor: Color {
        switch product.stockStatus {
        case .inStock:  return Color(.systemGreen)
        case .low:      return Color(.systemOrange)
        case .critical: return Color(.systemRed)
        }
    }

    private var quantityColor: Color {
        switch product.stockStatus {
        case .inStock:  return .primary
        case .low:      return Color(.systemOrange)
        case .critical: return Color(.systemRed)
        }
    }
}

// MARK: - Preview
#Preview {
    List {
        ProductRowView(product: Product(
            name: "White Cotton Fabric",
            category: "Fabric",
            quantity: 8,
            unit: "meters",
            reorderLevel: 10
        ))
        ProductRowView(product: Product(
            name: "Black Silk Thread",
            category: "Thread",
            quantity: 3,
            unit: "rolls",
            reorderLevel: 5,
            isFlaggedForReorder: true
        ))
        ProductRowView(product: Product(
            name: "Gold Buttons 12mm",
            category: "Accessories",
            quantity: 45,
            unit: "pcs",
            reorderLevel: 20
        ))
    }
    .listStyle(.insetGrouped)
}
