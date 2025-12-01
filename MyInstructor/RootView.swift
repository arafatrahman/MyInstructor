// File: arafatrahman/myinstructor/MyInstructor-main/MyInstructor/RootView.swift
// --- UPDATED: Removed "Instructors" tab for students to eliminate the "More" menu ---

import SwiftUI

// MARK: - Root View Router
struct RootView: View {
    @EnvironmentObject var authManager: AuthManager
    @EnvironmentObject var locationManager: LocationManager
    
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
                MainTabView()
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
                InstructorDashboardView()
                    .tabItem { Label("Dashboard", systemImage: "house.fill") }
                
                InstructorCalendarView()
                    .tabItem { Label("Calendar", systemImage: "calendar") }
                
                CommunityFeedView()
                    .tabItem { Label("Community", systemImage: "person.3.fill") }
                
                StudentsListView()
                    .tabItem { Label("Students", systemImage: "graduationcap.fill") }
                
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
                
                // 3. Live Map
                LiveLocationView(lesson: Lesson(instructorID: "", studentID: "", topic: "Live", startTime: Date(), pickupLocation: "Map View", fee: 0))
                    .tabItem { Label("Live Map", systemImage: "map.fill") }
                
                // 4. Community
                CommunityFeedView()
                    .tabItem { Label("Community", systemImage: "person.3.fill") }

                // REMOVED: MyInstructorsView tab.
                // It is now accessed via the "My Instructors" Quick Action on the Dashboard.
                
                // 5. Settings (Now takes the 5th slot, removing "More")
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
