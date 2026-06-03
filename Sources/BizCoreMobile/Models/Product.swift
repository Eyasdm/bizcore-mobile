import SwiftData
import Foundation

@Model
final class Product {

    // MARK: - Stored Properties
    var id: String
    var name: String
    var category: String
    var quantity: Int
    var unit: String
    var reorderLevel: Int
    var lastUpdated: Date
    var isFlaggedForReorder: Bool

    // MARK: - Computed Properties
    var stockStatus: StockStatus {
        if quantity < reorderLevel {
            return .critical
        } else if quantity < reorderLevel * 2 {
            return .low
        } else {
            return .inStock
        }
    }

    var statusLabel: String {
        stockStatus.label
    }

    // MARK: - Init
    init(
        id: String = UUID().uuidString,
        name: String,
        category: String,
        quantity: Int,
        unit: String,
        reorderLevel: Int,
        lastUpdated: Date = .now,
        isFlaggedForReorder: Bool = false
    ) {
        self.id = id
        self.name = name
        self.category = category
        self.quantity = quantity
        self.unit = unit
        self.reorderLevel = reorderLevel
        self.lastUpdated = lastUpdated
        self.isFlaggedForReorder = isFlaggedForReorder
    }
}

// MARK: - StockStatus Enum
enum StockStatus: String, Codable {
    case inStock   = "In Stock"
    case low       = "Low"
    case critical  = "Critical"

    var label: String { rawValue }

    var color: String {
        switch self {
        case .inStock:  return "statusGreen"
        case .low:      return "statusOrange"
        case .critical: return "statusRed"
        }
    }

    var sfSymbol: String {
        switch self {
        case .inStock:  return "checkmark.circle.fill"
        case .low:      return "exclamationmark.triangle.fill"
        case .critical: return "xmark.circle.fill"
        }
    }
}
