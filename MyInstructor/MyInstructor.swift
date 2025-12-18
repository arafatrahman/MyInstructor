import SwiftUI
import FirebaseCore
import Combine

// MARK: - App Delegate (For Firebase Setup)
class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        // Configure Firebase
        FirebaseApp.configure()
        print("Firebase configured successfully.")
        return true
    }
}

// MARK: - Main App Structure

@main
struct DrivingApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate
    
    // Initialize the core managers
    @StateObject var authManager = AuthManager()
    @StateObject var dataService = DataService()
    @StateObject var lessonManager = LessonManager()
    @StateObject var paymentManager = PaymentManager()
    @StateObject var communityManager = CommunityManager()
    @StateObject var locationManager = LocationManager()
    @StateObject var chatManager = ChatManager()
    @StateObject var expenseManager = ExpenseManager()
    @StateObject var vehicleManager = VehicleManager()
    @StateObject var contactManager = ContactManager()
    @StateObject var notificationManager = NotificationManager()
    @StateObject var personalEventManager = PersonalEventManager()
    
    // --- ADDED: Subscription Manager ---
    @StateObject var subscriptionManager = SubscriptionManager()

    var body: some Scene {
        WindowGroup {
            RootView()
                // Make managers available globally via the environment
                .environmentObject(authManager)
                .environmentObject(dataService)
                .environmentObject(lessonManager)
                .environmentObject(paymentManager)
                .environmentObject(communityManager)
                .environmentObject(locationManager)
                .environmentObject(chatManager)
                .environmentObject(expenseManager)
                .environmentObject(vehicleManager)
                .environmentObject(contactManager)
                .environmentObject(notificationManager)
                .environmentObject(personalEventManager)
                
                // --- INJECT Subscription Manager ---
                .environmentObject(subscriptionManager)
                
                // Apply the custom theme globally
                .applyAppTheme()
        }
    }
}
