import Foundation

/// Everything persisted locally. In a later iteration this JSON store is swapped for
/// CoreData + CloudKit behind the same interface (see AppStore).
struct AppData: Codable {
    var profile: UserProfile
    var transactions: [Transaction]

    static let empty = AppData(profile: UserProfile(), transactions: [])
}

/// Simple JSON-file persistence in the app's Documents directory.
/// Shared so the Shortcuts App Intent can append even when the UI isn't active.
final class PersistenceController {
    static let shared = PersistenceController()

    private let fileURL: URL
    private let queue = DispatchQueue(label: "com.budgetme.persistence")

    init(filename: String = "budgetme_store.json") {
        let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        fileURL = dir.appendingPathComponent(filename)
    }

    func load() -> AppData {
        queue.sync {
            guard let data = try? Data(contentsOf: fileURL),
                  let decoded = try? JSONDecoder.budget.decode(AppData.self, from: data)
            else { return .empty }
            return decoded
        }
    }

    func save(_ appData: AppData) {
        queue.sync {
            guard let data = try? JSONEncoder.budget.encode(appData) else { return }
            try? data.write(to: fileURL, options: .atomic)
        }
    }

    /// Used by the App Intent to log an Apple Pay transaction out-of-band.
    func appendTransaction(_ transaction: Transaction) {
        queue.sync {
            var current = (try? Data(contentsOf: fileURL))
                .flatMap { try? JSONDecoder.budget.decode(AppData.self, from: $0) } ?? .empty
            current.transactions.insert(transaction, at: 0)
            if let data = try? JSONEncoder.budget.encode(current) {
                try? data.write(to: fileURL, options: .atomic)
            }
        }
    }
}

extension JSONDecoder {
    static var budget: JSONDecoder {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }
}

extension JSONEncoder {
    static var budget: JSONEncoder {
        let e = JSONEncoder()
        e.dateEncodingStrategy = .iso8601
        return e
    }
}
