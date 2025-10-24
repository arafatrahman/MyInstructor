import SwiftUI
import FirebaseAuth

struct LoginForm: View {
    @EnvironmentObject var authManager: AuthManager
    
    // Form fields
    @State private var email = ""
    @State private var password = ""
    @State private var isLoading = false
    @State private var errorMessage: String?

    var body: some View {
        ScrollView {
            VStack(spacing: 30) {
                // Header
                VStack(alignment: .leading, spacing: 5) {
                    Text("Welcome Back")
                        .font(.largeTitle).bold()
                        .foregroundColor(.textDark)
                    Text("Sign in to continue your driving journey.")
                        .font(.subheadline)
                        .foregroundColor(.textLight)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top, 20)
                
                // Form Fields
                VStack(spacing: 15) {
                    // Email Input
                    TextField("Email", text: $email)
                        .textContentType(.emailAddress)
                        .keyboardType(.emailAddress)
                        .autocapitalization(.none)
                        .formTextFieldStyle()
                    
                    // Password Input
                    SecureField("Password", text: $password)
                        .textContentType(.password)
                        .formTextFieldStyle()
                    
                    // Forgot Password link
                    HStack {
                        Spacer()
                        Button("Forgot Password?") {
                            // TODO: Implement password reset flow
                            print("Forgot password tapped")
                        }
                        .font(.subheadline).bold()
                        .foregroundColor(.primaryBlue)
                    }
                }
                
                // Error Message
                if let error = errorMessage {
                    Text(error)
                        .foregroundColor(.warningRed)
                        .font(.caption)
                }
                
                // Login Button
                Button {
                    loginAction()
                } label: { // FIXED: Correct button syntax
                    HStack {
                        if isLoading {
                            ProgressView().tint(.white)
                        } else {
                            Text("Login")
                        }
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.primaryDrivingApp)
                .disabled(email.isEmpty || password.isEmpty || isLoading)
            }
        }
        .padding(.horizontal, 30)
    }
    
    // MARK: - Actions
    
    private func loginAction() {
        isLoading = true
        errorMessage = nil
        Task {
            do {
                try await authManager.login(email: email, password: password)
            } catch {
                if let errorCode = AuthErrorCode(rawValue: (error as NSError).code) {
                    switch errorCode {
                    case .invalidEmail, .wrongPassword, .userNotFound:
                        errorMessage = "Login failed. Please check your email and password."
                    case .tooManyRequests:
                        errorMessage = "Too many login attempts. Please try again later."
                    default:
                        errorMessage = "An unexpected error occurred during login."
                    }
                } else {
                    errorMessage = error.localizedDescription
                }
            }
            isLoading = false
        }
    }
}
