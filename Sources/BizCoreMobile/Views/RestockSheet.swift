import SwiftUI
import SwiftData

// MARK: - RestockSheet
// Bottom sheet for setting a product's stock level. Owned and presented by
// DashboardView via viewModel.showRestockSheet. The "Set stock level to" label
// is deliberate — confirmRestock SETS quantity = input, it does not add to it.
//
// Scratch state (restockQuantityText, selectedProduct) is cleared by
// DashboardView's .onChange(of: showRestockSheet) so every dismissal path —
// Confirm, Cancel, or swipe-down — leaves a clean slate for the next product.

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

// MARK: - Preview
#Preview("Restock") {
    RestockSheet(
        product: Product(
            name: "White Cotton Fabric",
            category: "Fabric",
            quantity: 8,
            unit: "meters",
            reorderLevel: 10
        ),
        viewModel: InventoryViewModel(),
        context: ModelContext(
            try! ModelContainer(
                for: Product.self,
                configurations: ModelConfiguration(isStoredInMemoryOnly: true)
            )
        )
    )
}
