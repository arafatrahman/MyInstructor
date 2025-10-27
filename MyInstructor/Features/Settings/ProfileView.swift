import SwiftUI

struct ProfileView: View {
    @EnvironmentObject var authManager: AuthManager
    
    // Profile settings state
    @State private var name: String = "John Doe" // Initialized with mock data
    @State private var hourlyRate: String = "45.00" // Instructor only
    
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
            }
            .navigationTitle("Profile")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}
