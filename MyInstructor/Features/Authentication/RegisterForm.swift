import SwiftUI
import FirebaseAuth

// --- Helper View for Modern Role Selection Card ---
struct RoleSelectionCard: View {
    let role: UserRole
    @Binding var selectedRole: UserRole
    let title: String
    let icon: String
    let color: Color
    
    var isSelected: Bool {
        selectedRole == role
    }
    
    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: icon)
                .font(.largeTitle)
                .foregroundColor(isSelected ? .white : color)
            
            Text(title)
                .font(.headline).bold()
                .foregroundColor(isSelected ? .white : .textDark)
        }
        .padding(.vertical, 25)
        .frame(maxWidth: .infinity)
        .background(isSelected ? color : Color.secondaryGray) // Highlight selected card
        .cornerRadius(10)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(isSelected ? color : Color.clear, lineWidth: 3) // Bold border on selection
        )
        .shadow(color: isSelected ? color.opacity(0.4) : Color.textDark.opacity(0.05), radius: 5, x: 0, y: 3)
        .onTapGesture {
            selectedRole = role
        }
    }
}
// ---------------------------------------------


struct RegisterForm: View {
    @EnvironmentObject var authManager: AuthManager
    @Binding var selection: Int // Binding for switching tabs
    
    // Form fields
    @State private var name = ""
    @State private var email = ""
    @State private var phone = ""
    @State private var password = ""
    @State private var selectedRole: UserRole = .student
    @State private var drivingSchool = ""
    
    @State private var isLoading = false
    @State private var errorMessage: String?

    var body: some View {
        ScrollView {
            VStack(spacing: 30) {
                
                // Icon removed as requested.

                // Role Selection Cards
                VStack(alignment: .leading, spacing: 10) {
                    Text("Select your role")
                        .font(.subheadline).bold()
                        .foregroundColor(.textDark)
                        .padding(.leading, 5)

                    HStack {
                        RoleSelectionCard(role: .student, selectedRole: $selectedRole, title: "Student", icon: "car.fill", color: .primaryBlue)
                        
                        RoleSelectionCard(role: .instructor, selectedRole: $selectedRole, title: "Instructor", icon: "person.fill.viewfinder", color: .accentGreen)
                    }
                }
                .padding(.horizontal, 30)
                
                // Form Fields
                VStack(spacing: 15) {
                    Group {
                        TextField("Full Name", text: $name)
                            .textContentType(.name)
                        
                        TextField("Email Address", text: $email)
                            .textContentType(.emailAddress)
                            .keyboardType(.emailAddress)
                            .autocapitalization(.none)
                        
                        SecureField("Create Password (min 6 chars)", text: $password)
                            .textContentType(.newPassword)

                        TextField("Phone (Optional)", text: $phone)
                            .textContentType(.telephoneNumber)
                            .keyboardType(.phonePad)

                        if selectedRole == .instructor {
                             TextField("Driving School (Optional)", text: $drivingSchool)
                                .transition(.opacity)
                        }
                    }
                    .formTextFieldStyle()
                }
                .padding(.horizontal, 30)
                
                // Error Message
                if let error = errorMessage {
                    Text(error)
                        .foregroundColor(.warningRed)
                        .font(.caption)
                        .padding(.horizontal, 30)
                }
                
                // Create Account Button
                Button {
                    registerAction()
                } label: {
                    HStack {
                        if isLoading {
                            ProgressView().tint(.white)
                        } else {
                            Text("Create Account")
                        }
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.primaryDrivingApp)
                .disabled(!isFormValid || isLoading)
                .padding(.horizontal, 30)

                // Modern Login link (switches the parent TabView selection)
                Button("Already have an account? Sign In") {
                    withAnimation {
                        selection = 0 // Switch to Login tab
                    }
                }
                .font(.subheadline).bold()
                .foregroundColor(.textLight)
            }
            .padding(.bottom, 40)
        }
    }
    
    // MARK: - Computed Properties and Actions
    
    private var isFormValid: Bool {
        !name.isEmpty && !email.isEmpty && !password.isEmpty && password.count >= 6
    }
    
    private func registerAction() {
        isLoading = true
        errorMessage = nil
        
        Task {
            do {
                try await authManager.signUp(
                    name: name,
                    email: email,
                    phone: phone,
                    password: password,
                    role: selectedRole,
                    drivingSchool: selectedRole == .instructor ? drivingSchool : nil
                )
            } catch {
                if let errorCode = AuthErrorCode(rawValue: (error as NSError).code) {
                    switch errorCode {
                    case .emailAlreadyInUse:
                        errorMessage = "Registration failed. This email is already in use."
                    case .weakPassword:
                        errorMessage = "Password is too weak. Please use 6 or more characters."
                    default:
                        errorMessage = "An unexpected error occurred during registration."
                    }
                } else {
                    errorMessage = error.localizedDescription
                }
            }
            isLoading = false
        }
    }
}
