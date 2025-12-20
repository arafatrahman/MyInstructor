import SwiftUI

// MARK: - Root View Router
struct RootView: View {
    @EnvironmentObject var authManager: AuthManager
    @EnvironmentObject var locationManager: LocationManager
    @EnvironmentObject var subscriptionManager: SubscriptionManager
    
    @State private var showSplash = true
    // Load initial state from UserDefaults
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
                    // --- FIX START ---
                    // 1. Save to UserDefaults so it persists
                    UserDefaults.standard.set(true, forKey: "hasSeenOnboarding")
                    
                    // 2. Update State to trigger transition
                    withAnimation {
                        self.hasSeenOnboarding = true
                    }
                    // --- FIX END ---
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
            // Keep state in sync with UserDefaults
            let storedValue = UserDefaults.standard.bool(forKey: "hasSeenOnboarding")
            if self.hasSeenOnboarding != storedValue {
                self.hasSeenOnboarding = storedValue
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
            if subscriptionManager.isPro {
                MainTabView()
            } else {
                PaywallView()
            }
        }
        // 3. Unselected or Error
        else {
             MainTabView()
        }
    }
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
                           Image("AppLogo")
                                               .resizable()
                                               .scaledToFit()
                                               .frame(width: 120, height: 120) // Slightly larger for better impact
                                               .clipShape(RoundedRectangle(cornerRadius: 24)) // Modern rounded corners
                                               .shadow(color: .black.opacity(0.2), radius: 10, x: 0, y: 5)
                           Text("Smart Lessons. Safe Driving.")
                               .font(.title2).bold()
                               .foregroundColor(.white)
                           
                           ProgressView(value: progress)
                               .progressViewStyle(LinearProgressViewStyle(tint: .white))
                               .frame(width: 150)
             }
            .onAppear {
                withAnimation(.spring(response: 0.6, dampingFraction: 0.7)) {
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
                InstructorDashboardView()
                    .tabItem { Label("Dashboard", systemImage: "house.fill") }
                
                InstructorCalendarView()
                    .tabItem { Label("Calendar", systemImage: "calendar") }
                
                CommunityFeedView()
                    .tabItem { Label("Broadcast", systemImage: "megaphone.fill") }
                
                StudentsListView()
                    .tabItem { Label("Students", systemImage: "person.2.fill") }
                
                SettingsView()
                    .tabItem { Label("Settings", systemImage: "gearshape.fill") }
                
            } else if authManager.role == .student {
                // Student Tabs
                StudentDashboardView()
                    .tabItem { Label("Dashboard", systemImage: "house.fill") }
                
                StudentCalendarView()
                    .tabItem { Label("Schedule", systemImage: "calendar") }
                
                CommunityFeedView()
                    .tabItem { Label("Broadcast", systemImage: "megaphone.fill") }
                
                MyInstructorsView()
                    .tabItem { Label("Instructors", systemImage: "person.2.fill") }

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
