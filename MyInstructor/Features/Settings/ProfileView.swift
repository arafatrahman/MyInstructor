// File: arafatrahman/myinstructor/MyInstructor-main/MyInstructor/Features/Settings/ProfileView.swift
import SwiftUI
import PhotosUI

// --- Helper View for Profile Rows (with Icons) ---
struct ProfileRow<Content: View>: View {
    let iconName: String
    let label: String
    @ViewBuilder let content: Content

    var body: some View {
        HStack(alignment: .center, spacing: 15) {
            Image(systemName: iconName)
                .foregroundColor(.primaryBlue)
                .frame(width: 20, alignment: .center)

            Text(label)
                .font(.subheadline)
                .foregroundColor(.textLight)
                .frame(width: 70, alignment: .leading) // Consistent label width

            content
                .foregroundColor(.textDark)
                .frame(maxWidth: .infinity, alignment: .trailing)
                .multilineTextAlignment(.trailing)
        }
        .padding(.vertical, 4) // Reduced vertical padding slightly
    }
}
// --- End Helper View ---


struct ProfileView: View {
    @EnvironmentObject var authManager: AuthManager

    // --- State variables remain the same ---
    @State private var name: String = ""
    @State private var phone: String = ""
    @State private var address: String = ""
    @State private var drivingSchool: String = ""
    @State private var hourlyRate: String = ""
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var selectedPhotoData: Data?
    @State private var isShowingAddressSearch = false
    @State private var isLoading = false
    @State private var statusMessage: (text: String, isError: Bool)?

    var isInstructor: Bool {
        authManager.role == .instructor
    }

    var userEmail: String {
        authManager.user?.email ?? "email@notfound.com"
    }

    // --- Profile Image ViewBuilder remains the same ---
    @ViewBuilder
    private var profileImageView: some View {
        // ... (profile image loading logic - no changes)
        if let photoData = selectedPhotoData, let uiImage = UIImage(data: photoData) {
            Image(uiImage: uiImage)
                .resizable().scaledToFill()
                .frame(width: 100, height: 100).clipShape(Circle())
                .overlay(Circle().stroke(Color.primaryBlue, lineWidth: 2))
        }
        else if let photoURLString = authManager.user?.photoURL, let url = URL(string: photoURLString) {
            AsyncImage(url: url) { phase in
                switch phase {
                case .empty: ProgressView().frame(width: 100, height: 100)
                case .success(let image):
                    image.resizable().scaledToFill()
                         .frame(width: 100, height: 100).clipShape(Circle())
                         .overlay(Circle().stroke(Color.primaryBlue.opacity(0.3), lineWidth: 1))
                case .failure:
                    Image(systemName: "person.circle.fill")
                        .resizable().scaledToFit()
                        .frame(width: 100, height: 100).foregroundColor(.secondaryGray)
                        .overlay(Circle().stroke(Color.warningRed.opacity(0.5), lineWidth: 1))
                @unknown default:
                    Image(systemName: "person.circle.fill")
                        .resizable().scaledToFit()
                        .frame(width: 100, height: 100).foregroundColor(.secondaryGray)
                }
            }
        }
        else {
            Image(systemName: "person.circle.fill")
                .resizable().scaledToFit()
                .frame(width: 100, height: 100).foregroundColor(.secondaryGray)
                .overlay(Circle().stroke(Color.textLight.opacity(0.3), lineWidth: 1))
        }
    }

    var body: some View {
        NavigationView {
            // Use Form directly for standard scrolling behavior
            Form {
                // MARK: - Profile Photo Section (Reduced Padding)
                Section {
                    VStack(spacing: 8) { // Tighter spacing
                        profileImageView
                        PhotosPicker(selection: $selectedPhotoItem, matching: .images, photoLibrary: .shared()) {
                            Text("Change Photo")
                                .font(.caption).foregroundColor(.primaryBlue)
                        }
                        .onChange(of: selectedPhotoItem, handlePhotoSelection)
                    }
                    .frame(maxWidth: .infinity) // Center align content
                    .padding(.vertical, 10) // Reduced vertical padding
                }
                // Match section background to default form background
                .listRowBackground(Color(.systemGroupedBackground))

                // MARK: - Personal Details Section
                Section("Personal Details") {
                    ProfileRow(iconName: "person.fill", label: "Name") {
                        TextField("Required", text: $name)
                    }
                    ProfileRow(iconName: "envelope.fill", label: "Email") {
                        Text(userEmail).foregroundColor(.textDark.opacity(0.7))
                    }
                    ProfileRow(iconName: "phone.fill", label: "Phone") {
                        TextField("Optional", text: $phone) .keyboardType(.phonePad)
                    }
                    ProfileRow(iconName: "location.fill", label: "Address") {
                        Button { isShowingAddressSearch = true } label: {
                            Text(address.isEmpty ? "Select Address" : address)
                                .foregroundColor(address.isEmpty ? Color(.placeholderText) : .textDark)
                                .lineLimit(2)
                                .frame(maxWidth: .infinity, alignment: .trailing)
                        }
                        // Add padding to make the button text area easier to tap within the row
                        .padding(.vertical, 5)
                    }
                }

                // MARK: - Instructor Section
                if isInstructor {
                    Section("Instructor Details") {
                        ProfileRow(iconName: "briefcase.fill", label: "School") {
                            TextField("Optional", text: $drivingSchool)
                        }
                        ProfileRow(iconName: "creditcard.fill", label: "Rate (£)") {
                            TextField("0.00", text: $hourlyRate)
                                .keyboardType(.decimalPad)
                                .foregroundColor(.primaryBlue)
                        }
                    }
                }

                // MARK: - Save Button & Status Message Section
                Section {
                    VStack(spacing: 10) { // VStack for spacing control
                        if isLoading {
                            ProgressView("Saving...")
                        } else {
                            Button("Save Changes") {
                                saveProfile()
                            }
                            // Apply button style HERE
                            .buttonStyle(.primaryDrivingApp)
                            // Ensure the button itself fills available width within the VStack
                            .frame(maxWidth: .infinity)
                        }

                        // Display status message below the button/progress view
                        if let msg = statusMessage {
                            Text(msg.text)
                                .font(.caption)
                                .foregroundColor(msg.isError ? .warningRed : .accentGreen)
                                .frame(maxWidth: .infinity, alignment: .center)
                                .padding(.top, 5) // Add space above message
                        }
                    }
                    .padding(.vertical, 5) // Add padding around the button/status
                }
                // Modifiers to make the button section look seamless
                .listRowInsets(EdgeInsets()) // Remove default Form insets
                .listRowBackground(Color.clear) // Make background clear

            } // End Form
            .navigationTitle("Edit Profile")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear(perform: loadUserData)
            .sheet(isPresented: $isShowingAddressSearch) {
                AddressSearchView { selectedAddressString in self.address = selectedAddressString }
            }
            .onChange(of: authManager.user?.id) { _, _ in loadUserData() }
            .onChange(of: authManager.user?.photoURL) { _, _ in loadUserData() }
        }
        .applyAppTheme() // Apply global theme settings
    }

    // --- HELPER FUNCTIONS (No changes needed) ---
    // ... (handlePhotoSelection, loadUserData, saveProfile remain the same)
    func handlePhotoSelection(oldItem: PhotosPickerItem?, newItem: PhotosPickerItem?) {
         Task {
            statusMessage = nil
            selectedPhotoData = nil // Clear previous temp data
            if let item = newItem {
                do {
                    selectedPhotoData = try await item.loadTransferable(type: Data.self)
                    if let data = selectedPhotoData {
                        print("ProfileView: New photo selected (\(data.count) bytes).")
                    } else {
                        statusMessage = (text: "Could not load selected photo.", isError: true)
                        print("!!! ProfileView: loadTransferable returned nil data.")
                    }
                } catch {
                    statusMessage = (text: "Error loading photo: \(error.localizedDescription)", isError: true)
                    print("!!! ProfileView: Failed to load data from PhotosPickerItem: \(error.localizedDescription)")
                }
            }
        }
    }

    func loadUserData() {
        guard let user = authManager.user else { return }
        print("ProfileView: Loading user data.")
        self.name = user.name ?? ""
        self.phone = user.phone ?? ""
        self.address = user.address ?? ""
        self.selectedPhotoData = nil
        self.selectedPhotoItem = nil

        if isInstructor {
            self.drivingSchool = user.drivingSchool ?? ""
            self.hourlyRate = String(format: "%.2f", user.hourlyRate ?? 0.0)
        }
        print("ProfileView: User data loaded.")
    }

    func saveProfile() {
        print("ProfileView: Save button tapped.")
        isLoading = true
        statusMessage = nil

        Task {
            do {
                print("ProfileView: Calling AuthManager.updateUserProfile...")
                try await authManager.updateUserProfile(
                    name: name,
                    phone: phone,
                    address: address,
                    drivingSchool: isInstructor ? drivingSchool : nil,
                    hourlyRate: isInstructor ? (Double(hourlyRate) ?? 0.0) : nil,
                    photoData: selectedPhotoData
                )
                print("ProfileView: AuthManager.updateUserProfile successful.")
                isLoading = false
                statusMessage = (text: "Profile updated successfully!", isError: false)
                selectedPhotoData = nil
                selectedPhotoItem = nil

            } catch {
                print("!!! ProfileView Save FAILED: \(error.localizedDescription)")
                isLoading = false
                statusMessage = (text: "Failed to update profile. \(error.localizedDescription)", isError: true)
            }
        }
    }
}
