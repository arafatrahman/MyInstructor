import SwiftUI
import StoreKit

struct PaywallView: View {
    @EnvironmentObject var subscriptionManager: SubscriptionManager
    @EnvironmentObject var authManager: AuthManager
    
    var body: some View {
        ZStack(alignment: .top) {
            // 1. Top Background (Blue Branding Area)
            Color.primaryBlue
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // MARK: - Header (Static on Blue)
                VStack(spacing: 10) {
                    Image(systemName: "crown.fill")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 45, height: 45)
                        .foregroundColor(.yellow)
                        .padding(12)
                        .background(Circle().fill(Color.white.opacity(0.15)))
                    
                    Text("Unlock Pro Access")
                        .font(.title).bold()
                        .foregroundColor(.white)
                    
                    Text("Take your driving school to the next level.")
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.9))
                }
                .padding(.top, 20)
                .padding(.bottom, 30)
                
                // MARK: - Content Sheet (White Background)
                ZStack {
                    Color.white
                        // Uses your project's existing cornerRadius extension if available
                        .clipShape(RoundedRectangle(cornerRadius: 30, style: .continuous))
                        .ignoresSafeArea(edges: .bottom)
                    
                    ScrollView(showsIndicators: false) {
                        VStack(spacing: 30) {
                            
                            // 1. Features Grid (3 Items per Row)
                            VStack(alignment: .leading, spacing: 15) {
                                Text("Pro Features")
                                    .font(.headline)
                                    .foregroundColor(.black)
                                    .padding(.leading, 5)
                                
                                LazyVGrid(columns: [
                                    GridItem(.flexible()),
                                    GridItem(.flexible()),
                                    GridItem(.flexible())
                                ], spacing: 15) {
                                    FeatureBox(icon: "person.2.fill", title: "Unlimited Students")
                                    FeatureBox(icon: "car.side.fill", title: "Vehicle Logs")
                                    FeatureBox(icon: "calendar.badge.clock", title: "Auto Schedule")
                                    FeatureBox(icon: "chart.bar.fill", title: "Finance Tracking")
                                    FeatureBox(icon: "lock.doc.fill", title: "Digital Vault")
                                    FeatureBox(icon: "plus.circle.fill", title: "More Features")
                                }
                            }
                            
                            // 2. Plans List
                            VStack(spacing: 15) {
                                Text("Choose a Plan")
                                    .font(.title3).bold()
                                    .foregroundColor(.black)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(.leading, 5)
                                
                                if subscriptionManager.isLoadingProducts {
                                    ProgressView()
                                        .tint(.black)
                                        .padding()
                                } else {
                                    ForEach(subscriptionManager.products) { product in
                                        Button {
                                            Task { try? await subscriptionManager.purchase(product) }
                                        } label: {
                                            ModernPlanCard(product: product)
                                        }
                                        .buttonStyle(PlainButtonStyle())
                                    }
                                }
                            }
                            
                            // 3. Footer / Restore
                            VStack(spacing: 15) {
                                Button {
                                    Task { await subscriptionManager.restorePurchases() }
                                } label: {
                                    Text("Restore Purchases")
                                        .font(.subheadline).bold()
                                        .foregroundColor(.primaryBlue)
                                        .padding(.vertical, 10)
                                        .padding(.horizontal, 20)
                                        .background(Color.primaryBlue.opacity(0.1))
                                        .cornerRadius(20)
                                }
                                
                                VStack(spacing: 5) {
                                    Text("Recurring billing. Cancel anytime.")
                                        .font(.caption)
                                        .foregroundColor(.gray)
                                    
                                    HStack(spacing: 15) {
                                        Link("Terms", destination: URL(string: "https://your-terms.com")!)
                                        Link("Privacy", destination: URL(string: "https://your-privacy.com")!)
                                    }
                                    .font(.caption2)
                                    .foregroundColor(.gray)
                                }
                            }
                            .padding(.bottom, 40)
                        }
                        .padding(25)
                    }
                }
                .environment(\.colorScheme, .light) // Forces Light Mode (Black Text)
            }
        }
    }
}

// MARK: - COMPONENTS

struct FeatureBox: View {
    let icon: String
    let title: String
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 22))
                .foregroundColor(.accentGreen)
            
            Text(title)
                .font(.caption).bold()
                .foregroundColor(.black)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 80)
        .background(Color(UIColor.systemGray6))
        .cornerRadius(12)
    }
}

struct ModernPlanCard: View {
    let product: Product
    
    var isBestValue: Bool {
        return product.id.contains("yearly")
    }
    
    // Helper to force specific names
    var planTitle: String {
        if product.id.contains("monthly") { return "Monthly Plan" }
        if product.id.contains("yearly") { return "Yearly Plan" }
        if product.id.contains("lifetime") { return "Lifetime Access" }
        return product.displayName
    }
    
    var body: some View {
        HStack {
            // Icon
            ZStack {
                Circle()
                    .fill(isBestValue ? Color.yellow.opacity(0.2) : Color.primaryBlue.opacity(0.1))
                    .frame(width: 45, height: 45)
                
                Image(systemName: isBestValue ? "star.fill" : "bag.fill")
                    .foregroundColor(isBestValue ? .orange : .primaryBlue)
                    .font(.system(size: 20))
            }
            
            // Text Section
            VStack(alignment: .leading, spacing: 4) {
                Text(planTitle)
                    .font(.headline)
                    .foregroundColor(.black)
                
                if isBestValue {
                    Text("Best Value")
                        .font(.caption2).bold()
                        .foregroundColor(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.orange)
                        .cornerRadius(4)
                } else {
                    Text(product.description)
                        .font(.caption)
                        .foregroundColor(.gray)
                        .lineLimit(1)
                }
            }
            // FIXED: Added padding top to center align the text visually
            .padding(.top, 15)
            
            Spacer()
            
            // Price Section
            VStack(alignment: .trailing) {
                Text(product.displayPrice)
                    .font(.title3).bold()
                    .foregroundColor(.primaryBlue)
                
                if let subscription = product.subscription {
                    Text("/ \(subscription.subscriptionPeriod.unit.localizedDescription)")
                        .font(.caption2)
                        .foregroundColor(.gray)
                } else {
                    Text("one-time")
                        .font(.caption2)
                        .foregroundColor(.gray)
                }
            }
        }
        .padding()
        .background(Color.white)
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(isBestValue ? Color.orange : Color(UIColor.systemGray5), lineWidth: isBestValue ? 2 : 1)
        )
        .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 3)
    }
}

// MARK: - EXTENSIONS

extension StoreKit.Product.SubscriptionPeriod.Unit {
    var localizedDescription: String {
        switch self {
        case .day: return "day"
        case .week: return "week"
        case .month: return "month"
        case .year: return "year"
        @unknown default: return "period"
        }
    }
}
