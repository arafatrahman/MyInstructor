import SwiftUI

// MARK: - Root View Router
struct RootView: View {
    @EnvironmentObject var authManager: AuthManager
    
    @State private var showSplash = true
    // State variable to track if Onboarding has been seen, initialized from UserDefaults
    @State private var hasSeenOnboarding: Bool = UserDefaults.standard.bool(forKey: "hasSeenOnboarding")
    
    var body: some View {
        Group {
            if showSplash {
                SplashScreenView(onFinish: { // Error resolved: Definition now included below
                    withAnimation {
                        self.showSplash = false
                    }
                })
            } else if !hasSeenOnboarding {
                OnboardingView(onComplete: {
                    // Action when onboarding is complete (Skip or Get Started clicked)
                    withAnimation {
                        self.hasSeenOnboarding = true
                    }
                })
            } else if !authManager.isAuthenticated {
                AuthenticationView()
            } else if authManager.role == .unselected {
                RoleSelectionView() // Error resolved: Definition now included below
            } else {
                MainTabView() // Error resolved: Definition now included below
            }
        }
        // Use NotificationCenter to watch for external UserDefaults changes, ensuring resilience
        .onReceive(NotificationCenter.default.publisher(for: UserDefaults.didChangeNotification)) { _ in
            if self.hasSeenOnboarding != UserDefaults.standard.bool(forKey: "hasSeenOnboarding") {
                self.hasSeenOnboarding = UserDefaults.standard.bool(forKey: "hasSeenOnboarding")
            }
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

// MARK: - Role Selection View (Flow 3)
struct RoleSelectionView: View {
    @EnvironmentObject var authManager: AuthManager
    @State private var selectedRole: UserRole? = nil
    @State private var isSaving: Bool = false
    
    var body: some View {
        VStack(spacing: 30) {
            Spacer()
            
            Text("Who are you?")
                .font(.largeTitle).bold()
                .padding(.bottom, 20)
            
            // Instructor Card
            RoleCard(role: .instructor, selectedRole: $selectedRole, title: "Instructor", icon: "person.fill.viewfinder")
                .accentColor(.primaryBlue)

            // Student Card
            RoleCard(role: .student, selectedRole: $selectedRole, title: "Student", icon: "car.fill")
                .accentColor(.accentGreen)

            Spacer()
            
            Button {
                guard let role = selectedRole else { return }
                isSaving = true
                Task {
                    try? await authManager.updateRole(to: role)
                    isSaving = false
                }
            } label: {
                Text(isSaving ? "Saving..." : "Continue")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.primaryDrivingApp)
            .disabled(selectedRole == nil || isSaving)
        }
        .padding(.horizontal, 30)
    }
}

// Helper view for RoleSelectionView
struct RoleCard: View {
    let role: UserRole
    @Binding var selectedRole: UserRole?
    let title: String
    let icon: String

    var body: some View {
        HStack {
            Image(systemName: icon)
                .resizable()
                .scaledToFit()
                .frame(width: 40, height: 40)
                .foregroundColor(role == .instructor ? .primaryBlue : .accentGreen)
            
            Text(title)
                .font(.title2).bold()
            
            Spacer()
            
            Image(systemName: selectedRole == role ? "checkmark.circle.fill" : "circle")
                .font(.title2)
                .foregroundColor(selectedRole == role ? .primaryBlue : .textLight)
        }
        .padding(20)
        .background(Color(.systemBackground))
        .cornerRadius(15)
        .shadow(color: Color.textLight.opacity(0.1), radius: 10, x: 0, y: 5)
        .overlay(
            RoundedRectangle(cornerRadius: 15)
                .stroke(selectedRole == role ? (role == .instructor ? .primaryBlue : .accentGreen) : Color.clear, lineWidth: 3)
        )
        .onTapGesture {
            selectedRole = role
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
                
                // Flow 12: Progress
                Text("Progress Tracker")
                    .tabItem { Label("Progress", systemImage: "book.fill") }
                
                // Flow 15: Settings
                SettingsView()
                    .tabItem { Label("Settings", systemImage: "gearshape.fill") }
            } else {
                Text("Error: Unknown Role").onAppear { try? authManager.logout() }
            }
        }
    }
}
