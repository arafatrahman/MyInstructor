// File: arafatrahman/myinstructor/MyInstructor-main/MyInstructor/RootView.swift
// --- THIS IS THE CORRECT, CLEAN FILE ---

import SwiftUI

// MARK: - Root View Router
struct RootView: View {
    @EnvironmentObject var authManager: AuthManager
    @EnvironmentObject var locationManager: LocationManager
    
    @State private var showSplash = true
    // State variable to track if Onboarding has been seen, initialized from UserDefaults
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
                // Show a loading spinner WHILE the profile is being fetched
                ProgressView()

            } else {
                // You only get here if you ARE authenticated AND you ARE NOT loading
                MainTabView()
            }
        }
        // Use NotificationCenter to watch for external UserDefaults changes, ensuring resilience
        .onReceive(NotificationCenter.default.publisher(for: UserDefaults.didChangeNotification)) { _ in
            if self.hasSeenOnboarding != UserDefaults.standard.bool(forKey: "hasSeenOnboarding") {
                self.hasSeenOnboarding = UserDefaults.standard.bool(forKey: "hasSeenOnboarding")
            }
        }
        .task {
            // As soon as the RootView is active (after splash),
            // request the user's location.
            await locationManager.requestLocation()
        }
    }
}

// ----------------------------------------------------------------------
// MARK: - AUXILIARY ROUTING VIEWS (Required for RootView to compile)
// ----------------------------------------------------------------------

// MARK: - Splash Screen View (Flow 1)
struct SplashScreenView: View {
    let onFinish: () -> Void
    @State private var progress: Double = 0
    
    var body: some View {
        ZStack {
            Color.primaryBlue.ignoresSafeArea()
            VStack(spacing: 20) {
                // Animated logo: Steering wheel → Map pin morph animation (Simple SwiftUI effect)
                Image(systemName: "steeringwheel")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 100)
                    .foregroundColor(.white)
                    .symbolEffect(.variableColor.iterative.reversing, options: .repeating, value: progress)
                
                Text("Smart Lessons. Safe Driving.") // Tagline
                    .font(.title2).bold()
                    .foregroundColor(.white)
                
                // Progress indicator bar
                ProgressView(value: progress)
                    .progressViewStyle(LinearProgressViewStyle(tint: .white))
                    .frame(width: 150)
            }
            .onAppear {
                // Simulate loading time
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
                // Flow 5: Instructor Dashboard
                InstructorDashboardView()
                    .tabItem { Label("Dashboard", systemImage: "house.fill") }
                
                // Flow 7: Calendar
                InstructorCalendarView()
                    .tabItem { Label("Calendar", systemImage: "calendar") }
                
                // Flow 18: Community
                CommunityFeedView()
                    .tabItem { Label("Community", systemImage: "person.3.fill") }
                
                // --- MESSAGES TAB REMOVED ---
                
                // Flow 11: Students
                StudentsListView()
                    .tabItem { Label("Students", systemImage: "graduationcap.fill") }
                
                // Flow 15: Settings
                SettingsView()
                    .tabItem { Label("Settings", systemImage: "gearshape.fill") }
                
            } else if authManager.role == .student {
                // Flow 6: Student Dashboard
                StudentDashboardView()
                    .tabItem { Label("Dashboard", systemImage: "house.fill") }
                
                // Flow 9: Live Map
                Text("Live Map View")
                    .tabItem { Label("Live Map", systemImage: "map.fill") }
                
                // Flow 18: Community
                CommunityFeedView()
                    .tabItem { Label("Community", systemImage: "person.3.fill") }

                // --- MESSAGES TAB REMOVED ---
                
                // The "My Instructors" tab
                MyInstructorsView()
                    .tabItem { Label("My Instructors", systemImage: "person.crop.rectangle.stack.fill") }
                
                // Flow 15: Settings
                SettingsView()
                    .tabItem { Label("Settings", systemImage: "gearshape.fill") }
            
            } else {
                // This state means auth succeeded but profile fetch failed (e.g., permissions error)
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
