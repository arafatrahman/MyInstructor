import SwiftUI
import FirebaseAuth
import PhotosUI // Import for PhotosPicker

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
            withAnimation { // <-- Add animation
                selectedRole = role
            }
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
    
    // --- ADDED/MODIFIED STATE ---
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var selectedPhotoData: Data?
    @State private var selectedAddress: String?
    @State private var isShowingAddressSearch = false
    @State private var hourlyRate: String = "45.00"
    // ------------------------------------
    
    @State private var isLoading = false
    @State private var errorMessage: String?

    var body: some View {
        ScrollView {
            VStack(spacing: 25) { // Increased spacing
                
                // --- ADDED PHOTO PICKER ---
                VStack {
                    PhotosPicker(
                        selection: $selectedPhotoItem,
                        matching: .images,
                        photoLibrary: .shared()
                    ) {
                        if let photoData = selectedPhotoData, let uiImage = UIImage(data: photoData) {
                            Image(uiImage: uiImage)
                                .resizable()
                                .scaledToFill()
                                .frame(width: 100, height: 100)
                                .clipShape(Circle())
                                .overlay(Circle().stroke(Color.primaryBlue, lineWidth: 2))
                        } else {
                            Image(systemName: "person.circle.fill")
                                .resizable()
                                .frame(width: 100, height: 100)
                                .foregroundColor(.secondaryGray)
                        }
                    }
                    .onChange(of: selectedPhotoItem) { newItem in
                        Task {
                            if let data = try? await newItem?.loadTransferable(type: Data.self) {
                                selectedPhotoData = data
                            }
                        }
                    }
                    
                    Text("Tap to add a profile photo")
                        .font(.caption)
                        .foregroundColor(.textLight)
                }
                .padding(.top, 10)
                // --------------------------

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
                
                // --- FORM FIELDS (RESTRUCTURED) ---
                VStack(spacing: 15) {
                    
                    // --- Fields for ALL users ---
                    TextField("Full Name", text: $name)
                        .textContentType(.name)
                        .formTextFieldStyle()
                    
                    TextField("Email Address", text: $email)
                        .textContentType(.emailAddress)
                        .keyboardType(.emailAddress)
                        .autocapitalization(.none)
                        .formTextFieldStyle()
                    
                    SecureField("Create Password (min 6 chars)", text: $password)
                        .textContentType(.newPassword)
                        .formTextFieldStyle()

                    TextField("Phone (Optional)", text: $phone)
                        .textContentType(.telephoneNumber)
                        .keyboardType(.phonePad)
                        .formTextFieldStyle()
                    
                    // --- Address Selection Button ---
                    Button {
                        isShowingAddressSearch = true
                    } label: {
                        HStack {
                            if let address = selectedAddress, !address.isEmpty {
                                Text(address)
                                    .foregroundColor(.textDark)
                                    .lineLimit(1)
                            } else {
                                Text("Select Address (Optional)")
                                    .foregroundColor(Color(.placeholderText)) // Use placeholder color
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .foregroundColor(.textLight)
                        }
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.secondaryGray)
                        .cornerRadius(10)
                    }
                }
                .padding(.horizontal, 30)
                
                // --- Fields for INSTRUCTOR only ---
                // This VStack is now *separate* and will appear/disappear
                if selectedRole == .instructor {
                    VStack(spacing: 15) {
                         TextField("Driving School (Optional)", text: $drivingSchool)
                            .formTextFieldStyle()
                        
                        HStack {
                            Text("Hourly Rate (£)")
                            Spacer()
                            TextField("Rate", text: $hourlyRate)
                                .keyboardType(.decimalPad)
                                .multilineTextAlignment(.trailing)
                        }
                        .padding()
                        .background(Color.secondaryGray)
                        .cornerRadius(10)
                    }
                    .padding(.horizontal, 30)
                    .transition(.opacity) // Add transition
                }
                // --- END OF RESTRUCTURED FORM ---
                
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

                // Modern Login link
                Button("Already have an account? Sign In") {
                    withAnimation {
                        selection = 0 // Switch to Login tab
                    }
                }
                .font(.subheadline).bold()
                .foregroundColor(.textLight)
            }
            .padding(.bottom, 40)
            .animation(.easeInOut(duration: 0.3), value: selectedRole) // Animate changes
            .sheet(isPresented: $isShowingAddressSearch) {
                AddressSearchView { selectedAddressString in
                    self.selectedAddress = selectedAddressString
                }
            }
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
                // --- UPDATED SIGNUP CALL ---
                try await authManager.signUp(
                    name: name,
                    email: email,
                    phone: phone,
                    password: password,
                    role: selectedRole,
                    drivingSchool: selectedRole == .instructor ? drivingSchool : nil,
                    address: selectedAddress,
                    photoData: selectedPhotoData,
                    hourlyRate: selectedRole == .instructor ? (Double(hourlyRate) ?? 0.0) : nil
                )
                // --------------------------
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
