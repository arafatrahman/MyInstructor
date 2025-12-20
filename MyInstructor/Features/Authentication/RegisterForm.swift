import SwiftUI
import FirebaseAuth
import PhotosUI

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
        VStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 30))
                .foregroundColor(isSelected ? .white : color)
            
            Text(title)
                .font(.subheadline).bold()
                .foregroundColor(isSelected ? .white : .textDark)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
        .background(isSelected ? color : Color.white)
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(isSelected ? 0.15 : 0.05), radius: 8, x: 0, y: 4)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(isSelected ? color : Color.secondaryGray, lineWidth: isSelected ? 0 : 1)
        )
        .scaleEffect(isSelected ? 1.02 : 1.0)
        .onTapGesture {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                selectedRole = role
            }
        }
    }
}

// --- Helper View for Input Rows with Icons ---
struct ModernInputRow: View {
    var icon: String
    var placeholder: String
    @Binding var text: String
    var isSecure: Bool = false
    var keyboardType: UIKeyboardType = .default
    var autoCapitalization: UITextAutocapitalizationType = .sentences
    
    var body: some View {
        HStack(spacing: 15) {
            Image(systemName: icon)
                .foregroundColor(.textLight)
                .frame(width: 24)
            
            if isSecure {
                SecureField(placeholder, text: $text)
                    .textContentType(.newPassword)
            } else {
                TextField(placeholder, text: $text)
                    .keyboardType(keyboardType)
                    .autocapitalization(autoCapitalization)
            }
        }
        .padding()
        .background(Color.white)
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.03), radius: 2, x: 0, y: 1)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.secondaryGray, lineWidth: 1)
        )
    }
}

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
        ScrollView(showsIndicators: false) {
            VStack(spacing: 30) {
                
                // --- SECTION 1: IDENTITY (Photo & Role) ---
                VStack(spacing: 20) {
                    // Photo Picker
                    PhotosPicker(
                        selection: $selectedPhotoItem,
                        matching: .images,
                        photoLibrary: .shared()
                    ) {
                        ZStack(alignment: .bottomTrailing) {
                            if let photoData = selectedPhotoData, let uiImage = UIImage(data: photoData) {
                                Image(uiImage: uiImage)
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: 110, height: 110)
                                    .clipShape(Circle())
                                    .overlay(Circle().stroke(Color.primaryBlue, lineWidth: 3))
                            } else {
                                Circle()
                                    .fill(Color.secondaryGray)
                                    .frame(width: 110, height: 110)
                                    .overlay(
                                        Image(systemName: "camera.fill")
                                            .font(.title)
                                            .foregroundColor(.textLight)
                                    )
                            }
                            
                            // Edit Badge
                            Image(systemName: "pencil.circle.fill")
                                .symbolRenderingMode(.palette)
                                .foregroundStyle(.white, Color.primaryBlue)
                                .font(.system(size: 32))
                                .offset(x: 4, y: 4)
                        }
                    }
                    .onChange(of: selectedPhotoItem) { newItem in
                        Task {
                            if let data = try? await newItem?.loadTransferable(type: Data.self) {
                                selectedPhotoData = data
                            }
                        }
                    }
                    
                    // Role Selection
                    HStack(spacing: 15) {
                        RoleSelectionCard(
                            role: .student,
                            selectedRole: $selectedRole,
                            title: "Student",
                            icon: "car.fill",
                            color: .primaryBlue
                        )
                        
                        RoleSelectionCard(
                            role: .instructor,
                            selectedRole: $selectedRole,
                            title: "Instructor",
                            icon: "person.fill.viewfinder",
                            color: .accentGreen
                        )
                    }
                }
                .padding(.horizontal, 25)
                
                // --- SECTION 2: PERSONAL INFO ---
                VStack(alignment: .leading, spacing: 15) {
                    Text("Personal Details")
                        .font(.caption).bold()
                        .foregroundColor(.textLight)
                        .padding(.leading, 5)
                    
                    ModernInputRow(
                        icon: "person",
                        placeholder: "Full Name",
                        text: $name,
                        autoCapitalization: .words
                    )
                    
                    ModernInputRow(
                        icon: "phone",
                        placeholder: "Phone Number (Optional)",
                        text: $phone,
                        keyboardType: .phonePad
                    )
                    
                    // Address Selector
                    Button {
                        isShowingAddressSearch = true
                    } label: {
                        HStack(spacing: 15) {
                            Image(systemName: "mappin.and.ellipse")
                                .foregroundColor(.textLight)
                                .frame(width: 24)
                            
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
                                .font(.caption)
                                .foregroundColor(.textLight)
                        }
                        .padding()
                        .background(Color.white)
                        .cornerRadius(12)
                        .shadow(color: Color.black.opacity(0.03), radius: 2, x: 0, y: 1)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.secondaryGray, lineWidth: 1)
                        )
                    }
                }
                .padding(.horizontal, 25)
                
                // --- SECTION 3: INSTRUCTOR SPECIFIC ---
                if selectedRole == .instructor {
                    VStack(alignment: .leading, spacing: 15) {
                        Text("Professional Info")
                            .font(.caption).bold()
                            .foregroundColor(.textLight)
                            .padding(.leading, 5)
                        
                        ModernInputRow(
                            icon: "building.2",
                            placeholder: "Driving School (Optional)",
                            text: $drivingSchool,
                            autoCapitalization: .words
                        )
                        
                        HStack(spacing: 15) {
                            Image(systemName: "sterlingsign.circle")
                                .foregroundColor(.textLight)
                                .frame(width: 24)
                            
                            Text("Hourly Rate")
                                .foregroundColor(.textDark)
                            
                            Spacer()
                            
                            TextField("0.00", text: $hourlyRate)
                                .keyboardType(.decimalPad)
                                .multilineTextAlignment(.trailing)
                                .frame(width: 100)
                        }
                        .padding()
                        .background(Color.white)
                        .cornerRadius(12)
                        .shadow(color: Color.black.opacity(0.03), radius: 2, x: 0, y: 1)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.secondaryGray, lineWidth: 1)
                        )
                    }
                    .padding(.horizontal, 25)
                    .transition(.move(edge: .top).combined(with: .opacity))
                }
                
                // --- SECTION 4: SECURITY ---
                VStack(alignment: .leading, spacing: 15) {
                    Text("Account Security")
                        .font(.caption).bold()
                        .foregroundColor(.textLight)
                        .padding(.leading, 5)
                    
                    ModernInputRow(
                        icon: "envelope",
                        placeholder: "Email Address",
                        text: $email,
                        keyboardType: .emailAddress,
                        autoCapitalization: .none
                    )
                    
                    ModernInputRow(
                        icon: "lock",
                        placeholder: "Create Password (min 6 chars)",
                        text: $password,
                        isSecure: true
                    )
                }
                .padding(.horizontal, 25)

                // Error Message
                if let error = errorMessage {
                    HStack {
                        Image(systemName: "exclamationmark.triangle.fill")
                        Text(error)
                    }
                    .foregroundColor(.warningRed)
                    .font(.caption)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 30)
                }
                
                // Action Buttons
                VStack(spacing: 20) {
                    Button {
                        registerAction()
                    } label: {
                        HStack {
                            if isLoading {
                                ProgressView().tint(.white)
                            } else {
                                Text("Create Account")
                                Image(systemName: "arrow.right")
                            }
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.primaryDrivingApp)
                    .disabled(!isFormValid || isLoading)
                    .opacity(!isFormValid ? 0.6 : 1.0)
                    
                    // Login link
                    Button {
                        withAnimation {
                            selection = 0 // Switch to Login tab
                        }
                    } label: {
                        HStack {
                            Text("Already have an account?")
                                .foregroundColor(.textLight)
                            Text("Sign In")
                                .bold()
                                .foregroundColor(.primaryBlue)
                        }
                        .font(.subheadline)
                    }
                }
                .padding(.horizontal, 25)
                .padding(.top, 10)
            }
            .padding(.bottom, 50)
            .animation(.easeInOut(duration: 0.3), value: selectedRole)
            .sheet(isPresented: $isShowingAddressSearch) {
                AddressSearchView { selectedAddressString in
                    self.selectedAddress = selectedAddressString
                }
            }
        }
        .background(Color(.systemGroupedBackground)) // Subtle light gray background for the whole form
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
                print("!!! SignUp FAILED: \(error.localizedDescription)")
                errorMessage = error.localizedDescription
                isLoading = false
            }
        }
    }
}
