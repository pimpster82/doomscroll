import StoreKit
import Foundation

// Manages all subscription state via StoreKit 2.
// Key rule (App Store guideline 3.1.3): FamilyControls authorization must be free
// for all users. Only the blocking features are gated behind subscription.
@MainActor
class SubscriptionManager: ObservableObject {
    static let shared = SubscriptionManager()

    // MARK: - Product IDs (must match App Store Connect exactly)

    enum ProductID {
        static let individualMonthly = "com.doomscroll.individual.monthly"
        static let individualAnnual  = "com.doomscroll.individual.annual"
        static let familyMonthly     = "com.doomscroll.family.monthly"
        static let familyAnnual      = "com.doomscroll.family.annual"

        static let all: [String] = [individualMonthly, individualAnnual, familyMonthly, familyAnnual]

        static let familyProducts: Set<String> = [familyMonthly, familyAnnual]
        static let annualProducts: Set<String>  = [individualAnnual, familyAnnual]
    }

    // MARK: - Published state

    @Published var products: [Product] = []
    @Published var activeSubscription: Product? = nil
    @Published var ownershipType: Transaction.OwnershipType? = nil
    @Published var isLoading = false

    // Derived

    var hasActiveAccess: Bool { activeSubscription != nil }

    // True if current user is a family plan beneficiary (not the purchaser)
    var isFamilyBeneficiary: Bool { ownershipType == .familyShared }

    var isFamilyPlan: Bool {
        guard let id = activeSubscription?.id else { return false }
        return ProductID.familyProducts.contains(id)
    }

    var isAnnualPlan: Bool {
        guard let id = activeSubscription?.id else { return false }
        return ProductID.annualProducts.contains(id)
    }

    // Formatted active plan name for UI
    var planDisplayName: String {
        guard let sub = activeSubscription else { return "Free Trial" }
        let family = isFamilyPlan ? "Family" : "Individual"
        let period = isAnnualPlan ? "Annual" : "Monthly"
        return "\(family) \(period)"
    }

    // MARK: - Lifecycle

    private var updateListenerTask: Task<Void, Never>? = nil

    private init() {
        updateListenerTask = listenForTransactionUpdates()
        Task {
            await loadProducts()
            await refreshEntitlements()
        }
    }

    deinit {
        updateListenerTask?.cancel()
    }

    // MARK: - Products

    func loadProducts() async {
        isLoading = true
        defer { isLoading = false }
        do {
            let fetched = try await Product.products(for: ProductID.all)
            products = fetched.sorted { $0.price < $1.price }
        } catch {
            // Products load on next app open; not fatal.
        }
    }

    func product(for id: String) -> Product? {
        products.first { $0.id == id }
    }

    // MARK: - Purchase

    func purchase(_ product: Product) async throws -> PurchaseResult {
        let result = try await product.purchase()
        switch result {
        case .success(let verification):
            let transaction = try verification.payloadValue
            await transaction.finish()
            await refreshEntitlements()
            return .success
        case .userCancelled:
            return .cancelled
        case .pending:
            return .pending
        @unknown default:
            return .cancelled
        }
    }

    func restorePurchases() async {
        try? await AppStore.sync()
        await refreshEntitlements()
    }

    // MARK: - Entitlements

    func refreshEntitlements() async {
        var found: Product? = nil
        var ownership: Transaction.OwnershipType? = nil

        for await result in Transaction.currentEntitlements {
            guard let transaction = try? result.payloadValue,
                  transaction.revocationDate == nil else { continue }
            found = products.first { $0.id == transaction.productID }
            ownership = transaction.ownershipType
            break
        }

        activeSubscription = found
        ownershipType = ownership
    }

    // MARK: - Transaction listener

    private func listenForTransactionUpdates() -> Task<Void, Never> {
        Task(priority: .background) { [weak self] in
            for await _ in Transaction.updates {
                await self?.refreshEntitlements()
            }
        }
    }

    enum PurchaseResult {
        case success, cancelled, pending
    }
}

// MARK: - Convenience for feature gating

extension SubscriptionManager {
    // Use this at every feature gate. Never gate the FamilyControls authorization itself.
    func requiresSubscription() -> Bool {
        !hasActiveAccess
    }
}
