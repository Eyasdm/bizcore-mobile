import SwiftUI
import Foundation

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
    /// Minimum 44×44pt tap target (Apple HIG) with full-area hit testing.
    /// .contentShape(Rectangle()) is required — without it, the tappable area
    /// only covers the view's visible content even after the frame is expanded.
    func minTapTarget() -> some View {
        self
            .frame(minWidth: 44, minHeight: 44)
            .contentShape(Rectangle())
    }
}