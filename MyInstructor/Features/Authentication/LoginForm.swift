import SwiftUI
import FirebaseAuth
import AuthenticationServices

struct LoginForm: View {
    @EnvironmentObject var authManager: AuthManager
    @Binding var selection: Int // Binding for switching tabs
    @Environment(\.colorScheme) var colorScheme
    
    // Form fields
    @State private var email = ""
    @State private var password = ""
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var successMessage: String? // ADDED: To show success for password reset
    
    // Apple Sign In
    @State private var currentNonce: String?

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
                            forgotPasswordAction() // UPDATED: Call action method
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
                
                // Success Message
                if let success = successMessage { // ADDED: Success message display
                    Text(success)
                        .foregroundColor(.accentGreen)
                        .font(.caption).bold()
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
                
                // --- Divider for Social Login ---
                HStack {
                    Rectangle().frame(height: 1).foregroundColor(.secondaryGray)
                    Text("OR").font(.caption).foregroundColor(.textLight)
                    Rectangle().frame(height: 1).foregroundColor(.secondaryGray)
                }
                .padding(.horizontal, 30)
                .padding(.vertical, 5)

                // --- Apple Sign In Button ---
                SignInWithAppleButton(
                    onRequest: { request in
                        let nonce = AuthManager.randomNonceString()
                        currentNonce = nonce
                        request.requestedScopes = [.fullName, .email]
                        request.nonce = AuthManager.sha256(nonce)
                    },
                    onCompletion: { result in
                        switch result {
                        case .success(let authorization):
                            if let appleIDCredential = authorization.credential as? ASAuthorizationAppleIDCredential {
                                guard let nonce = currentNonce else {
                                    errorMessage = "Invalid state: Missing nonce."
                                    return
                                }
                                signInWithAppleAction(credential: appleIDCredential, nonce: nonce)
                            }
                        case .failure(let error):
                            print("Apple Sign In Error: \(error.localizedDescription)")
                            // Usually, we don't show an error if the user just cancelled
                            if (error as NSError).code != ASAuthorizationError.canceled.rawValue {
                                errorMessage = "Apple Sign In failed."
                            }
                        }
                    }
                )
                .signInWithAppleButtonStyle(colorScheme == .dark ? .white : .black)
                .frame(height: 50)
                .cornerRadius(10)
                .padding(.horizontal, 30)

                // Modern Register link (switches the parent TabView selection)
                Button("Don't have an account? Sign Up") {
                    withAnimation {
                        selection = 1 // Switch to Register tab
                    }
                }
                .font(.subheadline).bold()
                .foregroundColor(.textLight)
                .padding(.top, 10)
            }
            .padding(.bottom, 40)
        }
    }
    
    // MARK: - Actions
    
    private func loginAction() {
        isLoading = true
        errorMessage = nil
        successMessage = nil // Clear messages on new login attempt
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
    
    private func signInWithAppleAction(credential: ASAuthorizationAppleIDCredential, nonce: String) {
        isLoading = true
        errorMessage = nil
        
        Task {
            do {
                try await authManager.signInWithApple(credential: credential, nonce: nonce)
                // Success is handled by AuthStateListener in AuthManager
            } catch {
                errorMessage = error.localizedDescription
                isLoading = false
            }
        }
    }
    
    private func forgotPasswordAction() {
        guard !email.isEmpty else {
            errorMessage = "Please enter your email address to reset your password."
            successMessage = nil
            return
        }
        
        isLoading = true
        errorMessage = nil
        successMessage = nil
        
        Task {
            do {
                try await authManager.sendPasswordReset(email: email)
                successMessage = "A password reset link has been sent to \(email)."
                errorMessage = nil // Ensure error message is cleared
            } catch {
                // Specific error handling for password reset
                if let errorCode = AuthErrorCode(rawValue: (error as NSError).code) {
                    switch errorCode {
                    case .invalidEmail:
                        errorMessage = "The email address is invalid."
                    case .userNotFound:
                        errorMessage = "No user found with this email address."
                    default:
                        errorMessage = "Failed to send password reset. Please try again."
                    }
                } else {
                    errorMessage = error.localizedDescription
                }
                successMessage = nil // Ensure success message is cleared
            }
            isLoading = false
        }
    }
}
