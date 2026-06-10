import Foundation

// MARK: - Supabase Configuration
// Create a Config.plist file in the project root with these keys:
//   SUPABASE_URL  → your project URL  e.g. https://xxxx.supabase.co
//   SUPABASE_KEY  → your anon/public key
// Config.plist is listed in .gitignore — never commit it

struct SupabaseConfig {
    static var url: String {
        guard let path = Bundle.main.path(forResource: "Config", ofType: "plist"),
              let dict = NSDictionary(contentsOfFile: path),
              let url = dict["SUPABASE_URL"] as? String else {
            return ""
        }
        return url
    }

    static var key: String {
        guard let path = Bundle.main.path(forResource: "Config", ofType: "plist"),
              let dict = NSDictionary(contentsOfFile: path),
              let key = dict["SUPABASE_KEY"] as? String else {
            return ""
        }
        return key
    }
}

// MARK: - Supabase REST Response Shape
struct SupabaseProduct: Codable {
    let id: String
    let name: String
    let category: String
    let quantity: Int
    let unit: String
    let reorder_level: Int
    let updated_at: String?
    let flagged_for_reorder: Bool?

    func toProduct() -> Product {
        Product(
            id: id,
            name: name,
            category: category,
            quantity: quantity,
            unit: unit,
            reorderLevel: reorder_level,
            lastUpdated: parseDate(updated_at) ?? .now,
            isFlaggedForReorder: flagged_for_reorder ?? false
        )
    }

    private func parseDate(_ string: String?) -> Date? {
        guard let string else { return nil }
        let formatter = ISO8601DateFormatter()
        return formatter.date(from: string)
    }
}

// MARK: - Supabase Service
actor SupabaseService {

    static let shared = SupabaseService()

    private var baseURL: String { SupabaseConfig.url }
    private var apiKey: String  { SupabaseConfig.key }

    private var headers: [String: String] {
        [
            "apikey":        apiKey,
            "Authorization": "Bearer \(apiKey)",
            "Content-Type":  "application/json",
            "Prefer":        "return=representation"
        ]
    }

    // MARK: - Fetch All Products
    func fetchProducts() async throws -> [SupabaseProduct] {
        guard !baseURL.isEmpty else {
            throw SupabaseError.missingConfig
        }

        let urlString = "\(baseURL)/rest/v1/products?select=*&order=name.asc"
        guard let url = URL(string: urlString) else {
            throw SupabaseError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        headers.forEach { request.setValue($1, forHTTPHeaderField: $0) }

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw SupabaseError.serverError
        }

        // Distinguish a transport/server failure from a payload we couldn't parse,
        // so the user sees an accurate message instead of a generic server error.
        do {
            return try JSONDecoder().decode([SupabaseProduct].self, from: data)
        } catch {
            throw SupabaseError.decodingError
        }
    }

    // MARK: - Update Quantity (Restock)
    func updateQuantity(productID: String, newQuantity: Int) async throws {
        guard !baseURL.isEmpty else {
            throw SupabaseError.missingConfig
        }

        let urlString = "\(baseURL)/rest/v1/products?id=eq.\(productID)"
        guard let url = URL(string: urlString) else {
            throw SupabaseError.invalidURL
        }

        let body: [String: Any] = [
            "quantity":   newQuantity,
            "updated_at": ISO8601DateFormatter().string(from: .now)
        ]

        var request = URLRequest(url: url)
        request.httpMethod = "PATCH"
        headers.forEach { request.setValue($1, forHTTPHeaderField: $0) }
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (_, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw SupabaseError.serverError
        }
    }

    // MARK: - Update Flag
    func updateFlag(productID: String, flagged: Bool) async throws {
        guard !baseURL.isEmpty else {
            throw SupabaseError.missingConfig
        }

        let urlString = "\(baseURL)/rest/v1/products?id=eq.\(productID)"
        guard let url = URL(string: urlString) else {
            throw SupabaseError.invalidURL
        }

        let body: [String: Any] = ["flagged_for_reorder": flagged]

        var request = URLRequest(url: url)
        request.httpMethod = "PATCH"
        headers.forEach { request.setValue($1, forHTTPHeaderField: $0) }
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (_, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw SupabaseError.serverError
        }
    }
}

// MARK: - Errors
enum SupabaseError: LocalizedError {
    case missingConfig
    case invalidURL
    case serverError
    case decodingError

    var errorDescription: String? {
        switch self {
        case .missingConfig:  return "Supabase credentials not configured. Check Config.plist."
        case .invalidURL:     return "Invalid request URL."
        case .serverError:    return "Server returned an error. Check your connection."
        case .decodingError:  return "Failed to decode server response."
        }
    }
}
