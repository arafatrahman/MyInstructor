import Foundation
import StoreKit
import SwiftUI
import Combine

@MainActor
class SubscriptionManager: ObservableObject {
    @Published var products: [Product] = []
    @Published var purchasedProductIDs: Set<String> = []
    @Published var isLoadingProducts: Bool = false
    
    // Computed property to check if user has access (Paid)
    var isPro: Bool {
        return !purchasedProductIDs.isEmpty
    }
    
    // Configure your Product IDs here as set up in App Store Connect
    private let productIDs: [String] = [
        "com.myinstructor.monthly", // £4.99
        "com.myinstructor.yearly",  // £49.99
        "com.myinstructor.lifetime" // £99.99
    ]
    
    private var updates: Task<Void, Never>? = nil
    
    init() {
        self.updates = newTransactionListenerTask()
        Task {
            await fetchProducts()
            await updatePurchasedStatus()
        }
    }
    
    deinit {
        updates?.cancel()
    }
    
    // MARK: - Fetch Products
    func fetchProducts() async {
        self.isLoadingProducts = true
        do {
            let products = try await Product.products(for: productIDs)
            // Sort by price for consistent display: Monthly < Yearly < Lifetime
            self.products = products.sorted(by: { $0.price < $1.price })
        } catch {
            print("Failed to fetch products: \(error)")
        }
        self.isLoadingProducts = false
    }
    
    // MARK: - Purchase Logic
    func purchase(_ product: Product) async throws {
        let result = try await product.purchase()
        
        switch result {
        case .success(let verification):
            // Check if the transaction is verified
            switch verification {
            case .verified(let transaction):
                await transaction.finish()
                await updatePurchasedStatus()
            case .unverified(_, let error):
                print("Unverified transaction: \(error.localizedDescription)")
                throw error
            }
        case .userCancelled:
            break
        case .pending:
            break
        @unknown default:
            break
        }
    }
    
    // MARK: - Listen for Transactions
    // Keeps track of transactions happening outside the app (e.g. renewal, family sharing)
    private func newTransactionListenerTask() -> Task<Void, Never> {
        Task(priority: .background) {
            for await verification in Transaction.updates {
                switch verification {
                case .verified(let transaction):
                    await transaction.finish()
                    await self.updatePurchasedStatus()
                case .unverified:
                    break
                }
            }
        }
    }
    
    // MARK: - Check Entitlements
    func updatePurchasedStatus() async {
        var purchased: Set<String> = []
        
        // Check current entitlements
        for await result in Transaction.currentEntitlements {
            switch result {
            case .verified(let transaction):
                // Check if it's not revoked
                if transaction.revocationDate == nil {
                    purchased.insert(transaction.productID)
                }
            case .unverified:
                break
            }
        }
        
        self.purchasedProductIDs = purchased
    }
    
    // MARK: - Restore Purchases
    func restorePurchases() async {
        try? await AppStore.sync()
        await updatePurchasedStatus()
    }
}
