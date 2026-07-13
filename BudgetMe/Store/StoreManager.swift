import Foundation
import StoreKit

/// StoreKit 2 wrapper: loads subscription products, handles purchase/restore, and tracks whether
/// the user currently has an active entitlement. Note: our own `Transaction` model collides with
/// StoreKit's, so StoreKit types are fully qualified as `StoreKit.Transaction`.
@MainActor
final class StoreManager: ObservableObject {
    @Published private(set) var products: [Product] = []
    @Published private(set) var isSubscribed = false

    private let productIDs = ["com.budgetme.pro.monthly", "com.budgetme.pro.annual"]
    private var updatesTask: Task<Void, Never>?

    init() {
        updatesTask = listenForTransactions()
        Task {
            await loadProducts()
            await refreshSubscriptionStatus()
        }
    }

    deinit { updatesTask?.cancel() }

    func loadProducts() async {
        do {
            products = try await Product.products(for: productIDs).sorted { $0.price < $1.price }
        } catch {
            print("StoreKit: failed to load products — \(error)")
        }
    }

    @discardableResult
    func purchase(_ product: Product) async -> Bool {
        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                if case .verified(let transaction) = verification {
                    await transaction.finish()
                    await refreshSubscriptionStatus()
                    return true
                }
                return false
            case .userCancelled, .pending:
                return false
            @unknown default:
                return false
            }
        } catch {
            return false
        }
    }

    func restore() async {
        try? await StoreKit.AppStore.sync()
        await refreshSubscriptionStatus()
    }

    func refreshSubscriptionStatus() async {
        var active = false
        for await result in StoreKit.Transaction.currentEntitlements {
            if case .verified(let transaction) = result,
               productIDs.contains(transaction.productID),
               transaction.revocationDate == nil {
                active = true
            }
        }
        isSubscribed = active
    }

    private func listenForTransactions() -> Task<Void, Never> {
        Task(priority: .background) { [weak self] in
            for await result in StoreKit.Transaction.updates {
                if case .verified(let transaction) = result {
                    await transaction.finish()
                }
                await self?.refreshSubscriptionStatus()
            }
        }
    }
}
