import SwiftUI

// Flow Item 15: Settings
struct SettingsView: View {
    @EnvironmentObject var authManager: AuthManager
    
    // Profile settings state (Initialized with mock/default data for demo)
    @State private var name: String = "John Doe"
    @State private var hourlyRate: String = "45.00" // Instructor only
    
    // Privacy and toggles
    @State private var isLocationSharingEnabled = true
    @State private var receiveLessonReminders = true
    @State private var receiveCommunityAlerts = true
    @State private var isProgressPublic = false // Privacy (Community, Progress sharing)
    @State private var isPrivacyConsentShowing = false
    
    var isInstructor: Bool {
        authManager.role == .instructor
    }
    
    var userEmail: String {
        authManager.user?.email ?? "email@notfound.com"
    }

    var body: some View {
        NavigationView {
            Form {
                // MARK: - Profile Section
                Section("Profile & Rates") {
                    TextField("Name", text: $name)
                    HStack {
                        Text("Email")
                        Spacer()
                        Text(userEmail)
                            .foregroundColor(.textLight)
                    }
                    .disabled(true)
                    
                    if isInstructor {
                        HStack {
                            Text("Hourly Rate (£)")
                            Spacer()
                            TextField("Rate", text: $hourlyRate)
                                .keyboardType(.decimalPad)
                                .multilineTextAlignment(.trailing)
                        }
                    }
                    
                    Button("Save Profile Changes") {
                        // TODO: Update user profile in AuthManager/Firestore
                        print("Profile updated with Name: \(name), Rate: \(hourlyRate)")
                    }
                    .foregroundColor(.primaryBlue)
                }
                
                // MARK: - Location & Privacy (Flow 16)
                Section("Location & Sharing") {
                    Toggle("Enable Live Location Sharing", isOn: $isLocationSharingEnabled)
                        .onChange(of: isLocationSharingEnabled) { newValue in
                            if newValue {
                                isPrivacyConsentShowing = true // Trigger consent on enabling
                            }
                        }
                        .tint(.primaryBlue)
                    
                    if isInstructor {
                        Toggle("Auto-Share Pickup Location with Students", isOn: .constant(true))
                            .tint(.primaryBlue)
                    }
                    
                    Toggle("Share Progress on Community Feed", isOn: $isProgressPublic)
                        .tint(.primaryBlue)

                    Text("Live location is shared only during active lessons. Progress sharing is optional.")
                        .font(.caption)
                        .foregroundColor(.textLight)
                }
                
                // MARK: - Notification Preferences (Flow 14 context)
                Section("Notification Preferences") {
                    Toggle("Lesson Reminders", isOn: $receiveLessonReminders)
                        .tint(.primaryBlue)
                    Toggle("Payment Alerts (Due/Received)", isOn: .constant(true))
                        .tint(.primaryBlue)
                    Toggle("Community Activity Alerts", isOn: $receiveCommunityAlerts)
                        .tint(.primaryBlue)
                }
                
                // MARK: - App Actions
                Section {
                    Button("Export data") {
                         // TODO: Initiate data export process
                        print("Data export requested.")
                    }
                    Button("Logout", role: .destructive) {
                        try? authManager.logout()
                    }
                }
            }
            .navigationTitle("Settings")
            .sheet(isPresented: $isPrivacyConsentShowing) {
                PrivacyConsentPopup(isLocationSharingEnabled: $isLocationSharingEnabled)
            }
        }
    }
}

// Flow Item 16: Privacy & Consent Popup
struct PrivacyConsentPopup: View {
    @Environment(\.dismiss) var dismiss
    @Binding var isLocationSharingEnabled: Bool
    
    var body: some View {
        VStack(spacing: 25) {
            Image(systemName: "location.fill.viewfinder")
                .font(.system(size: 60))
                .foregroundColor(.primaryBlue)
            
            Text("Live Location Consent")
                .font(.largeTitle).bold()
            
            Text("When you share your live location, it's visible **only** to your current student/instructor **during active lessons** or shortly before.")
                .multilineTextAlignment(.center)
                .padding(.horizontal)
                .foregroundColor(.textDark)
            
            VStack(spacing: 15) {
                Button("Allow Always") {
                    // This sets the app permission and enables the toggle
                    isLocationSharingEnabled = true
                    dismiss()
                }
                .buttonStyle(.primaryDrivingApp)
                
                Button("Deny") {
                    isLocationSharingEnabled = false
                    dismiss()
                }
                .foregroundColor(.textLight)
            }
        }
        .padding(30)
    }
}