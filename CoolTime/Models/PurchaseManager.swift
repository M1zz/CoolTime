import StoreKit
import Foundation

@Observable
final class PurchaseManager {
    static let shared = PurchaseManager()

    private(set) var isPro: Bool
    private(set) var product: Product?
    private(set) var isLoading = false
    var purchaseError: String?

    static let freeItemLimit = 3
    static let freeStatsDays = 7

    private let lifetimeID = "com.cooltime.pro.lifetime"

    private var listenerTask: Task<Void, Never>?

    private init() {
        isPro = UserDefaults.standard.bool(forKey: "cooltime.isPro")
        listenerTask = Self.startTransactionListener(manager: self)
        Task {
            await loadProducts()
            await refreshEntitlements()
        }
    }

    deinit {
        listenerTask?.cancel()
    }

    // MARK: - Products

    func loadProducts() async {
        await MainActor.run { isLoading = true }
        do {
            let fetched = try await Product.products(for: [lifetimeID])
            await MainActor.run {
                product = fetched.first
                isLoading = false
            }
        } catch {
            await MainActor.run { isLoading = false }
        }
    }

    // MARK: - Purchase

    func purchase() async {
        guard let product else { return }
        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                let transaction = try verify(verification)
                await setPro(true)
                await transaction.finish()
            case .userCancelled, .pending:
                break
            @unknown default:
                break
            }
        } catch {
            await MainActor.run { purchaseError = error.localizedDescription }
        }
    }

    // MARK: - Restore

    func restore() async {
        do {
            try await AppStore.sync()
            await refreshEntitlements()
        } catch {
            await MainActor.run { purchaseError = "구매 복원에 실패했어요" }
        }
    }

    // MARK: - Entitlements

    func refreshEntitlements() async {
        var hasActive = false
        for await result in Transaction.currentEntitlements {
            if case .verified(let tx) = result,
               tx.productID == lifetimeID,
               tx.revocationDate == nil {
                hasActive = true
            }
        }
        await setPro(hasActive)
    }

    // MARK: - Private

    private func setPro(_ value: Bool) async {
        await MainActor.run {
            isPro = value
            UserDefaults.standard.set(value, forKey: "cooltime.isPro")
            WidgetDataStore.saveIsPro(value)
        }
    }

    private static func startTransactionListener(manager: PurchaseManager) -> Task<Void, Never> {
        Task(priority: .background) {
            for await result in Transaction.updates {
                if case .verified(let tx) = result {
                    await manager.setPro(tx.revocationDate == nil)
                    await tx.finish()
                }
            }
        }
    }

    private func verify<T>(_ result: VerificationResult<T>) throws -> T {
        guard case .verified(let value) = result else {
            throw PurchaseManagerError.failedVerification
        }
        return value
    }
}

enum PurchaseManagerError: LocalizedError {
    case failedVerification
    var errorDescription: String? { "구매 검증에 실패했어요" }
}
