import Foundation
import CoreData

/// Everything persisted locally, encoded into a single CoreData record.
/// Kept as Codable so it can be JSON-encoded into the store blob (and exported).
struct AppData: Codable {
    var profile: UserProfile
    var transactions: [Transaction]
    var subscriptions: [Subscription] = []
    var customCategories: [String] = []
    var debts: [Debt] = []
    var savingsGoals: [SavingsGoal] = []
    var plannedEntries: [PlannedEntry] = []

    static let empty = AppData(profile: UserProfile(), transactions: [])
}

/// CoreData-backed persistence. Stores the whole app state as one record so models and views
/// stay untouched. Built programmatically (no .xcdatamodeld) and ready to switch to
/// `NSPersistentCloudKitContainer` for cross-device sync once an iCloud-enabled account is set up.
/// Shared so the Shortcuts App Intent can append even when the UI isn't active.
final class PersistenceController {
    static let shared = PersistenceController()

    private let container: NSPersistentContainer
    private let recordID = "budgetme_appdata"
    private let entityName = "StoreBlob"

    private lazy var context: NSManagedObjectContext = {
        let ctx = container.newBackgroundContext()
        ctx.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        return ctx
    }()

    init(inMemory: Bool = false) {
        // Programmatic model: one entity holding an id + a JSON payload blob.
        let model = NSManagedObjectModel()
        let entity = NSEntityDescription()
        entity.name = entityName
        entity.managedObjectClassName = NSStringFromClass(NSManagedObject.self)

        let idAttr = NSAttributeDescription()
        idAttr.name = "id"
        idAttr.attributeType = .stringAttributeType
        idAttr.isOptional = true

        let payloadAttr = NSAttributeDescription()
        payloadAttr.name = "payload"
        payloadAttr.attributeType = .binaryDataAttributeType
        payloadAttr.isOptional = true
        payloadAttr.allowsExternalBinaryDataStorage = true

        entity.properties = [idAttr, payloadAttr]
        model.entities = [entity]

        container = NSPersistentContainer(name: "BudgetMe", managedObjectModel: model)
        if inMemory {
            container.persistentStoreDescriptions.first?.url = URL(fileURLWithPath: "/dev/null")
        }
        // Load synchronously so the store is ready before the first read.
        container.persistentStoreDescriptions.first?.shouldAddStoreAsynchronously = false
        container.loadPersistentStores { _, error in
            if let error { print("CoreData load error: \(error)") }
        }
    }

    func load() -> AppData {
        var result = AppData.empty
        context.performAndWait {
            if let obj = fetchRecord(),
               let data = obj.value(forKey: "payload") as? Data,
               let decoded = try? JSONDecoder.budget.decode(AppData.self, from: data) {
                result = decoded
            } else if let legacy = loadLegacyJSON() {
                // One-time migration from the old JSON file so no data is lost.
                writeRecord(legacy)
                result = legacy
            }
        }
        return result
    }

    func save(_ appData: AppData) {
        context.performAndWait { writeRecord(appData) }
    }

    /// Used by the App Intent to log an Apple Pay transaction out-of-band (any thread).
    func appendTransaction(_ transaction: Transaction) {
        context.performAndWait {
            var current: AppData = .empty
            if let obj = fetchRecord(),
               let data = obj.value(forKey: "payload") as? Data,
               let decoded = try? JSONDecoder.budget.decode(AppData.self, from: data) {
                current = decoded
            } else if let legacy = loadLegacyJSON() {
                current = legacy
            }
            current.transactions.insert(transaction, at: 0)
            writeRecord(current)
        }
    }

    // MARK: - Private

    private func fetchRecord() -> NSManagedObject? {
        let request = NSFetchRequest<NSManagedObject>(entityName: entityName)
        request.predicate = NSPredicate(format: "id == %@", recordID)
        request.fetchLimit = 1
        return (try? context.fetch(request))?.first
    }

    private func writeRecord(_ appData: AppData) {
        guard let data = try? JSONEncoder.budget.encode(appData) else { return }
        let obj = fetchRecord() ?? NSEntityDescription.insertNewObject(forEntityName: entityName, into: context)
        obj.setValue(recordID, forKey: "id")
        obj.setValue(data, forKey: "payload")
        try? context.save()
    }

    private func loadLegacyJSON() -> AppData? {
        let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let url = dir.appendingPathComponent("budgetme_store.json")
        guard let data = try? Data(contentsOf: url),
              let decoded = try? JSONDecoder.budget.decode(AppData.self, from: data) else { return nil }
        return decoded
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
