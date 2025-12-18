import SwiftUI
import StoreKit

struct PaywallView: View {
    @EnvironmentObject var subscriptionManager: SubscriptionManager
    @EnvironmentObject var authManager: AuthManager
    
    var body: some View {
        ZStack {
            Color.primaryBlue.ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: 25) {
                    // Header
                    VStack(spacing: 10) {
                        Image(systemName: "crown.fill")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 60, height: 60)
                            .foregroundColor(.yellow)
                            .padding(.top, 40)
                        
                        Text("Upgrade to Pro")
                            .font(.largeTitle).bold()
                            .foregroundColor(.white)
                        
                        Text("Your 3-day free trial has ended.\nSubscribe to continue managing your students.")
                            .multilineTextAlignment(.center)
                            .foregroundColor(.white.opacity(0.9))
                            .padding(.horizontal)
                    }
                    
                    // Features List
                    VStack(alignment: .leading, spacing: 15) {
                        FeatureRow(text: "Unlimited Student Management")
                        FeatureRow(text: "Automatic Lesson Scheduling")
                        FeatureRow(text: "Income & Expense Tracking")
                        FeatureRow(text: "Digital Vault for Documents")
                        FeatureRow(text: "Community Access")
                    }
                    .padding()
                    .background(Color.white.opacity(0.1))
                    .cornerRadius(12)
                    .padding(.horizontal)
                    
                    // Products
                    if subscriptionManager.isLoadingProducts {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .scaleEffect(1.5)
                            .padding()
                    } else {
                        VStack(spacing: 12) {
                            ForEach(subscriptionManager.products) { product in
                                Button {
                                    Task {
                                        try? await subscriptionManager.purchase(product)
                                    }
                                } label: {
                                    ProductRow(product: product)
                                }
                            }
                        }
                        .padding(.horizontal)
                    }
                    
                    // Restore Button
                    Button("Restore Purchases") {
                        Task {
                            await subscriptionManager.restorePurchases()
                        }
                    }
                    .font(.footnote)
                    .foregroundColor(.white.opacity(0.7))
                    .padding(.top)
                    
                    // Terms & Privacy (Required by Apple)
                    VStack(spacing: 5) {
                        Text("Recurring billing, cancel anytime.")
                        HStack {
                            Link("Terms of Service", destination: URL(string: "https://your-terms-url.com")!)
                            Text("•")
                            Link("Privacy Policy", destination: URL(string: "https://your-privacy-url.com")!)
                        }
                    }
                    .font(.caption2)
                    .foregroundColor(.white.opacity(0.5))
                    .padding(.bottom, 30)
                }
            }
        }
    }
}

struct FeatureRow: View {
    let text: String
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundColor(.green)
            Text(text)
                .foregroundColor(.white)
                .font(.body)
            Spacer()
        }
    }
}

struct ProductRow: View {
    let product: Product
    
    var body: some View {
        HStack {
            VStack(alignment: .leading) {
                Text(product.displayName)
                    .font(.headline)
                    .foregroundColor(.primaryBlue)
                Text(product.description)
                    .font(.caption)
                    .foregroundColor(.gray)
                    .lineLimit(1)
            }
            Spacer()
            Text(product.displayPrice)
                .bold()
                .foregroundColor(.primaryBlue)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(Color.primaryBlue.opacity(0.1))
                .cornerRadius(8)
        }
        .padding()
        .background(Color.white)
        .cornerRadius(12)
    }
}
