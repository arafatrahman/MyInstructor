import SwiftUI

// MARK: - Root View Router
struct RootView: View {
    @EnvironmentObject var authManager: AuthManager
    @EnvironmentObject var locationManager: LocationManager
    @EnvironmentObject var subscriptionManager: SubscriptionManager
    
    @State private var showSplash = true
    @State private var hasSeenOnboarding: Bool = UserDefaults.standard.bool(forKey: "hasSeenOnboarding")
    
    var body: some View {
        Group {
            if showSplash {
                SplashScreenView(onFinish: {
                    withAnimation {
                        self.showSplash = false
                    }
                })
            } else if !hasSeenOnboarding {
                OnboardingView(onComplete: {
                    withAnimation {
                        self.hasSeenOnboarding = true
                    }
                })
            } else if !authManager.isAuthenticated {
                AuthenticationView()
            
            } else if authManager.isLoading {
                ProgressView()

            } else {
                // --- Subscription Logic Check ---
                checkSubscriptionAndRoute()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: UserDefaults.didChangeNotification)) { _ in
            if self.hasSeenOnboarding != UserDefaults.standard.bool(forKey: "hasSeenOnboarding") {
                self.hasSeenOnboarding = UserDefaults.standard.bool(forKey: "hasSeenOnboarding")
            }
        }
        .task {
            await locationManager.requestLocation()
        }
    }
    
    // MARK: - Routing Logic
    @ViewBuilder
    func checkSubscriptionAndRoute() -> some View {
        // 1. Students are always Free
        if authManager.role == .student {
            MainTabView()
        }
        // 2. Instructors Check
        else if authManager.role == .instructor {
            // PRODUCTION LOGIC:
            // Only allow access if 'isPro' is true.
            // 'isPro' becomes true if they buy a subscription OR start an Apple Free Trial.
            if subscriptionManager.isPro {
                MainTabView()
            } else {
                // If they haven't paid or started a trial via Apple, show Paywall immediately.
                PaywallView()
            }
        }
        // 3. Unselected or Error
        else {
             MainTabView()
        }
    }
    
    // REMOVED: isWithinGracePeriod()
    // Reason: In production, you rely on Apple's 'Introductory Offer' (Free Trial) configured in App Store Connect.
}

// ----------------------------------------------------------------------
// MARK: - AUXILIARY ROUTING VIEWS
// ----------------------------------------------------------------------

// MARK: - Splash Screen View (Flow 1)
struct SplashScreenView: View {
    let onFinish: () -> Void
    @State private var progress: Double = 0
    
    var body: some View {
        ZStack {
            Color.primaryBlue.ignoresSafeArea()
            VStack(spacing: 20) {
                Image(systemName: "steeringwheel")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 100)
                    .foregroundColor(.white)
                    .symbolEffect(.variableColor.iterative.reversing, options: .repeating, value: progress)
                
                Text("Smart Lessons. Safe Driving.")
                    .font(.title2).bold()
                    .foregroundColor(.white)
                
                ProgressView(value: progress)
                    .progressViewStyle(LinearProgressViewStyle(tint: .white))
                    .frame(width: 150)
            }
            .onAppear {
                withAnimation(.linear(duration: 1.5)) {
                    progress = 1.0
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.8) {
                    onFinish()
                }
            }
        }
    }
}

// MARK: - Main Tab View (Container for Dashboards)
struct MainTabView: View {
    @EnvironmentObject var authManager: AuthManager
    
    var body: some View {
        TabView {
            if authManager.role == .instructor {
                // Instructor Tabs
                
                // 1. Dashboard
                InstructorDashboardView()
                    .tabItem { Label("Dashboard", systemImage: "house.fill") }
                
                // 2. Calendar
                InstructorCalendarView()
                    .tabItem { Label("Calendar", systemImage: "calendar") }
                
                // 3. Broadcast
                CommunityFeedView()
                    .tabItem { Label("Broadcast", systemImage: "megaphone.fill") }
                
                // 4. Students
                StudentsListView()
                    .tabItem { Label("Students", systemImage: "person.2.fill") }
                
                // 5. Settings
                SettingsView()
                    .tabItem { Label("Settings", systemImage: "gearshape.fill") }
                
            } else if authManager.role == .student {
                // Student Tabs
                
                // 1. Dashboard
                StudentDashboardView()
                    .tabItem { Label("Dashboard", systemImage: "house.fill") }
                
                // 2. Schedule
                StudentCalendarView()
                    .tabItem { Label("Schedule", systemImage: "calendar") }
                
                // 3. Broadcast
                CommunityFeedView()
                    .tabItem { Label("Broadcast", systemImage: "megaphone.fill") }
                
                // 4. Instructors
                MyInstructorsView()
                    .tabItem { Label("Instructors", systemImage: "person.2.fill") }

                // 5. Settings
                SettingsView()
                    .tabItem { Label("Settings", systemImage: "gearshape.fill") }
            
            } else {
                // Error State
                VStack(spacing: 15) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.largeTitle)
                        .foregroundColor(.warningRed)
                    Text("Error Loading Profile")
                        .font(.title).bold()
                    Text("We couldn't load your user data. Please check your network connection or try again.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                    
                    Button("Logout and Try Again") {
                        try? authManager.logout()
                    }
                    .buttonStyle(.primaryDrivingApp)
                    .padding()
                }
            }
        }
    }
}
