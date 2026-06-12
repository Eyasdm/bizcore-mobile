import Foundation

// Persisted via didSet → UserDefaults in NotificationViewModel (@Observable
// is incompatible with @AppStorage). Not a SwiftData model.

struct NotificationSettings {
    static let defaultCheckFrequencyHours: Int = 4
    static let defaultQuietStart: Int = 22  // 10 PM
    static let defaultQuietEnd: Int = 7     // 7 AM
}

enum CheckFrequency: Int, CaseIterable, Identifiable {
    case oneHour    = 1
    case fourHours  = 4
    case daily      = 24

    var id: Int { rawValue }

    var label: String {
        switch self {
        case .oneHour:   return "Every hour"
        case .fourHours: return "Every 4 hours"
        case .daily:     return "Once a day"
        }
    }
}
