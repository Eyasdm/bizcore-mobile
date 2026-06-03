import SwiftUI
import Foundation

// MARK: - Color Extensions
extension Color {
    static var statusGreen: Color  { Color("statusGreen")  }
    static var statusOrange: Color { Color("statusOrange") }
    static var statusRed: Color    { Color("statusRed")    }
    static var accent: Color       { Color("AccentColor")  }

    static func forStatus(_ status: StockStatus) -> Color {
        switch status {
        case .inStock:  return .statusGreen
        case .low:      return .statusOrange
        case .critical: return .statusRed
        }
    }
}

// MARK: - Date Extensions
extension Date {
    var shortFormatted: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter.string(from: self)
    }

    var relativeFormatted: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: self, relativeTo: .now)
    }
}

// MARK: - View Extensions
extension View {
    /// Applies a minimum tap target size of 44x44pt (Apple HIG requirement)
    func minTapTarget() -> some View {
        self.frame(minWidth: 44, minHeight: 44)
    }
}
