import SwiftUI
import FirebaseAuth

struct LoginForm: View {
    @EnvironmentObject var authManager: AuthManager
    @Binding var selection: Int // Binding for switching tabs
    
    // Form fields
    @State private var email = ""
    @State private var password = ""
    @State private var isLoading = false
    @State private var errorMessage: String?

    var body: some View {
        ScrollView {
            VStack(spacing: 30) {
                
                // --- Modern Login Icon ---
                Image(systemName: "lock.shield.fill")
                    .font(.system(size: 80))
                    .foregroundColor(.primaryBlue)
                    .padding(.top, 20)

                // Form Fields
                VStack(spacing: 15) {
                    // Email Input
                    TextField("Email Address", text: $email)
                        .textContentType(.emailAddress)
                        .keyboardType(.emailAddress)
                        .autocapitalization(.none)
                        .formTextFieldStyle()
                    
                    // Password Input
                    SecureField("Password", text: $password)
                        .textContentType(.password)
                        .formTextFieldStyle()
                    
                    // Forgot Password link (Aligned with new design)
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
                .padding(.horizontal, 30)

                // Error Message
                if let error = errorMessage {
                    Text(error)
                        .foregroundColor(.warningRed)
                        .font(.caption)
                        .padding(.horizontal, 30)
                }
                
                // Login Button
                Button {
                    loginAction()
                } label: {
                    HStack {
                        if isLoading {
                            ProgressView().tint(.white)
                        } else {
                            Text("Sign In")
                        }
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.primaryDrivingApp)
                .disabled(email.isEmpty || password.isEmpty || isLoading)
                .padding(.horizontal, 30)

                // Modern Register link (switches the parent TabView selection)
                Button("Don't have an account? Sign Up") {
                    withAnimation {
                        selection = 1 // Switch to Register tab
                    }
                }
                .font(.subheadline).bold()
                .foregroundColor(.textLight)
            }
            .padding(.bottom, 40)
        }
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
