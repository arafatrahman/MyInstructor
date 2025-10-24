import SwiftUI
import FirebaseAuth

struct RegisterForm: View {
    @EnvironmentObject var authManager: AuthManager
    
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
                // Header
                VStack(alignment: .leading, spacing: 5) {
                    Text("Create New Account")
                        .font(.largeTitle).bold()
                        .foregroundColor(.textDark)
                    Text("Join us in making smart, safe drivers.")
                        .font(.subheadline)
                        .foregroundColor(.textLight)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top, 20)
                
                // Form Fields
                VStack(spacing: 15) { // FIXED: Changed VVStack to VStack
                    Group {
                        TextField("Full Name", text: $name)
                            .textContentType(.name)
                        
                        TextField("Email", text: $email)
                            .textContentType(.emailAddress)
                            .keyboardType(.emailAddress)
                            .autocapitalization(.none)
                        
                        TextField("Phone (Optional)", text: $phone)
                            .textContentType(.telephoneNumber)
                            .keyboardType(.phonePad)
                        
                        SecureField("Password (min 6 characters)", text: $password)
                            .textContentType(.newPassword)
                    }
                    .formTextFieldStyle()
                    
                    // Role Dropdown
                    VStack(alignment: .leading) {
                        Text("Account Role")
                            .font(.caption).foregroundColor(.textLight)
                        
                        Picker("Role", selection: $selectedRole) {
                            Label("Student", systemImage: "car.fill").tag(UserRole.student)
                            Label("Instructor", systemImage: "person.fill.viewfinder").tag(UserRole.instructor)
                        }
                        .pickerStyle(.menu)
                        .padding(.horizontal)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.secondaryGray)
                        .cornerRadius(10)
                    }
                    
                    // Driving School (Conditional for Instructor role)
                    if selectedRole == .instructor {
                        TextField("Driving School (Optional)", text: $drivingSchool)
                            .formTextFieldStyle()
                            .transition(.opacity)
                    }
                }
                
                // Error Message
                if let error = errorMessage {
                    Text(error)
                        .foregroundColor(.warningRed)
                        .font(.caption)
                }
                
                // Create Account Button
                Button {
                    registerAction()
                } label: { // FIXED: Correct button syntax
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
            }
        }
        .padding(.horizontal, 30)
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
