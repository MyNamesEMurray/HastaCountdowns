import Foundation
import Observation
import StoreKit
import WidgetKit

@MainActor
@Observable
final class PurchaseManager {
    private(set) var product: Product?
    private(set) var isPremium: Bool
    private(set) var isPurchasing = false
    var errorMessage: String?

    @ObservationIgnored private var updatesTask: Task<Void, Never>?

    init() {
        isPremium = Premium.isUnlocked
        updatesTask = Task { [weak self] in
            for await result in StoreKit.Transaction.updates {
                await self?.handle(result)
            }
        }
        Task {
            await loadProduct()
            await refreshEntitlements()
        }
    }

    var displayPrice: String? {
        product?.displayPrice
    }

    func loadProduct() async {
        do {
            product = try await Product.products(for: [Premium.productID]).first
        } catch {
            product = nil
        }
    }

    func purchase() async {
        if product == nil {
            await loadProduct()
        }
        guard let product else {
            errorMessage = "Hasta Premium isn't available right now. Please try again later."
            return
        }
        isPurchasing = true
        defer { isPurchasing = false }
        do {
            switch try await product.purchase() {
            case .success(let verification):
                await handle(verification)
            case .pending:
                errorMessage = "Your purchase is pending approval. Premium will unlock as soon as it's approved."
            case .userCancelled:
                break
            @unknown default:
                break
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func restore() async {
        isPurchasing = true
        defer { isPurchasing = false }
        do {
            try await AppStore.sync()
        } catch {
            errorMessage = error.localizedDescription
        }
        await refreshEntitlements()
        if !isPremium && errorMessage == nil {
            errorMessage = "No previous purchase was found for this Apple Account."
        }
    }

    func refreshEntitlements() async {
        var unlocked = false
        for await result in StoreKit.Transaction.currentEntitlements {
            if case .verified(let transaction) = result,
               transaction.productID == Premium.productID,
               transaction.revocationDate == nil {
                unlocked = true
            }
        }
        setPremium(unlocked)
    }

    private func handle(_ result: VerificationResult<StoreKit.Transaction>) async {
        guard case .verified(let transaction) = result else { return }
        if transaction.productID == Premium.productID {
            setPremium(transaction.revocationDate == nil)
        }
        await transaction.finish()
    }

    private func setPremium(_ value: Bool) {
        guard value != isPremium || value != Premium.isUnlocked else { return }
        isPremium = value
        Premium.isUnlocked = value
        WidgetCenter.shared.reloadAllTimelines()
    }
}
