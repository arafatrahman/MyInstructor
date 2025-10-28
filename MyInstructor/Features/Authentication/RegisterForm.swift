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
        .background(isSelected ? color : Color.secondaryGray)
        .cornerRadius(10)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(isSelected ? color : Color.clear, lineWidth: 3)
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
    @Binding var selection: Int
    
    // Form fields
    @State private var name = ""
    @State private var email = ""
    @State private var phone = ""
    @State private var password = ""
    @State private var selectedRole: UserRole = .student
    @State private var drivingSchool = ""
    
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var selectedPhotoData: Data?
    @State private var selectedAddress: String?
    @State private var isShowingAddressSearch = false
    @State private var hourlyRate: String = "45.00"
    
    @State private var isLoading = false
    @State private var errorMessage: String?

    var body: some View {
        ScrollView {
            VStack(spacing: 25) {
                
                // --- PHOTO PICKER ---
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

                // --- ROLE SELECTION ---
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
                
                // --- COMMON FORM FIELDS ---
                VStack(spacing: 15) {
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
                                    .foregroundColor(Color(.placeholderText))
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
                
                // --- INSTRUCTOR-ONLY FIELDS (THIS IS THE FIX) ---
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
                    .transition(.opacity.combined(with: .scale(scale: 0.95)))
                }
                
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

                // Login link
                Button("Already have an account? Sign In") {
                    withAnimation {
                        selection = 0 // Switch to Login tab
                    }
                }
                .font(.subheadline).bold()
                .foregroundColor(.textLight)
            }
            .padding(.bottom, 40)
            .animation(.easeInOut(duration: 0.3), value: selectedRole)
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
                // On success, the AuthManager's listener will handle the navigation
                
            } catch {
                // If signUp throws an error, show it
                print("!!! SignUp FAILED: \(error.localizedDescription)")
                errorMessage = error.localizedDescription
                isLoading = false
            }
            // Don't set isLoading = false here, as success is handled by the listener
        }
    }
}
