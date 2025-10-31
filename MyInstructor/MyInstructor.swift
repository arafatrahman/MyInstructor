// File: arafatrahman/myinstructor/MyInstructor-main/MyInstructor/MyInstructor.swift
// --- This is the correct content for this file ---

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
    
    // --- *** ADD THIS LINE *** ---
    @StateObject var chatManager = ChatManager()

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
                
                // --- *** ADD THIS LINE *** ---
                .environmentObject(chatManager)
                
                // Apply the custom theme globally
                .applyAppTheme()
        }
    }
}
