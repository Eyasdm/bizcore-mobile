import SwiftUI

// MARK: - StatusBadge
// Reusable badge showing In Stock / Low / Critical
// Used in ProductRowView and ProductDetailView

struct StatusBadge: View {

    let status: StockStatus

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: status.sfSymbol)
                .font(.caption2)
            Text(status.label)
                .font(.caption2)
                .fontWeight(.semibold)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(backgroundColor)
        .foregroundStyle(foregroundColor)
        .clipShape(Capsule())
        // Without .accessibilityElement(children: .ignore), VoiceOver reads both
        // the SF Symbol name AND the label text as separate elements, producing
        // something like "exclamationmark dot triangle dot fill Low".
        // Combined label gives "Status: Low" which is accurate and concise.
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Status: \(status.label)")
    }

    // MARK: - Colors (semantic — dark mode safe)
    private var backgroundColor: Color {
        switch status {
        case .inStock:  return Color(.systemGreen).opacity(0.15)
        case .low:      return Color(.systemOrange).opacity(0.15)
        case .critical: return Color(.systemRed).opacity(0.15)
        }
    }

    private var foregroundColor: Color {
        switch status {
        case .inStock:  return Color(.systemGreen)
        case .low:      return Color(.systemOrange)
        case .critical: return Color(.systemRed)
        }
    }
}

// MARK: - Preview
#Preview {
    VStack(spacing: 16) {
        StatusBadge(status: .inStock)
        StatusBadge(status: .low)
        StatusBadge(status: .critical)
    }
    .padding()
}