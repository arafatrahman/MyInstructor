// File: arafatrahman/myinstructor/MyInstructor-main/MyInstructor/Features/Settings/ProfileView.swift
import SwiftUI
import PhotosUI

struct ProfileView: View {
    @EnvironmentObject var authManager: AuthManager
    
    // --- STATE FOR ALL EDITABLE FIELDS ---
    @State private var name: String = ""
    @State private var phone: String = ""
    @State private var address: String = ""
    @State private var drivingSchool: String = ""
    @State private var hourlyRate: String = ""

    // --- STATE FOR PHOTO PICKER ---
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var selectedPhotoData: Data? // Holds data from picker TEMPORARILY
    
    // --- STATE FOR UI AND ACTIONS ---
    @State private var isShowingAddressSearch = false
    @State private var isLoading = false
    @State private var statusMessage: (text: String, isError: Bool)? // Unified status message
    
    var isInstructor: Bool {
        authManager.role == .instructor
    }
    
    var userEmail: String {
        authManager.user?.email ?? "email@notfound.com"
    }
    
    // Displays the profile image: New selection > Existing URL > Placeholder
    @ViewBuilder
    private var profileImageView: some View {
        // Priority 1: Show newly selected image if present
        if let photoData = selectedPhotoData, let uiImage = UIImage(data: photoData) {
            Image(uiImage: uiImage)
                .resizable()
                .scaledToFill()
                .frame(width: 120, height: 120)
                .clipShape(Circle())
                .overlay(Circle().stroke(Color.primaryBlue, lineWidth: 3))
                .onAppear {
                    print("ProfileView: Displaying newly selected photo data.")
                }
        }
        // Priority 2: Show existing image from URL if available
        else if let photoURLString = authManager.user?.photoURL, let url = URL(string: photoURLString) {
            // Using AsyncImage (iOS 15+)
            AsyncImage(url: url) { phase in
                switch phase {
                case .empty:
                    ProgressView()
                        .frame(width: 120, height: 120)
                        .onAppear { print("ProfileView: Loading image from URL: \(url)") } // Log URL
                case .success(let image):
                    image
                        .resizable()
                        .scaledToFill()
                        .frame(width: 120, height: 120)
                        .clipShape(Circle())
                        .overlay(Circle().stroke(Color.primaryBlue.opacity(0.5), lineWidth: 2))
                        .onAppear { print("ProfileView: Successfully loaded image from URL.") } // Log success
                case .failure(let error):
                    // Show placeholder if loading fails
                    Image(systemName: "person.circle.fill")
                        .resizable()
                        .frame(width: 120, height: 120)
                        .foregroundColor(.secondaryGray)
                        .overlay(Circle().stroke(Color.warningRed, lineWidth: 2)) // Indicate error
                        .onAppear { print("!!! ProfileView: Failed to load image from URL: \(url). Error: \(error.localizedDescription)") } // Log failure
                @unknown default:
                    EmptyView()
                }
            }
        }
        // Priority 3: Show placeholder if no selection and no URL
        else {
            Image(systemName: "person.circle.fill")
                .resizable()
                .frame(width: 120, height: 120)
                .foregroundColor(.secondaryGray)
                .overlay(Circle().stroke(Color.textLight.opacity(0.3), lineWidth: 2))
                .onAppear { print("ProfileView: Displaying placeholder image.") } // Log placeholder
        }
    }

    var body: some View {
        NavigationView {
            Form {
                // MARK: - Profile Photo Section
                Section {
                    VStack(spacing: 15) {
                        profileImageView // Use the ViewBuilder computed property
                        
                        Text(name) // Display name loaded from AuthManager
                            .font(.title2).bold()
                            .foregroundColor(.textDark)
                        
                        Text(userEmail)
                            .font(.subheadline)
                            .foregroundColor(.textLight)

                        // Button to trigger PhotosPicker
                        PhotosPicker(
                            selection: $selectedPhotoItem,
                            matching: .images, // Only allow images
                            photoLibrary: .shared()
                        ) {
                            Text("Change Photo")
                                .font(.headline)
                                .foregroundColor(.primaryBlue)
                        }
                        .onChange(of: selectedPhotoItem) { newItem in
                            Task {
                                // Clear previous status message when selecting a new photo
                                statusMessage = nil
                                selectedPhotoData = nil // Clear previous data first
                                if let data = try? await newItem?.loadTransferable(type: Data.self) {
                                    selectedPhotoData = data
                                    print("ProfileView: New photo selected (\(data.count) bytes).")
                                } else if newItem != nil {
                                    // Handle case where loading data failed
                                    statusMessage = (text: "Could not load selected photo.", isError: true)
                                    print("!!! ProfileView: Failed to load data from PhotosPickerItem.")
                                }
                            }
                        }
                    }
                    .frame(maxWidth: .infinity) // Center the VStack content
                    .padding(.vertical, 10)
                }
                
                // MARK: - Personal Details Section
                Section("Personal Details") {
                    TextField("Name", text: $name)
                    
                    TextField("Phone", text: $phone)
                        .keyboardType(.phonePad)
                    
                    Button {
                        isShowingAddressSearch = true
                    } label: {
                        VStack(alignment: .leading, spacing: 3) {
                            Text("Address")
                                .font(.caption)
                                .foregroundColor(address.isEmpty ? .textLight : .primaryBlue) // More contrast
                            Text(address.isEmpty ? "Select Address" : address)
                                .foregroundColor(address.isEmpty ? Color(.placeholderText) : .textDark) // Use placeholder color
                                .lineLimit(2)
                        }
                        .padding(.vertical, 4)
                    }
                }
                
                // MARK: - Instructor Section
                if isInstructor {
                    Section("Instructor Details") {
                        TextField("Driving School", text: $drivingSchool)
                        
                        HStack {
                            Text("Hourly Rate (£)")
                            Spacer()
                            TextField("Rate", text: $hourlyRate)
                                .keyboardType(.decimalPad)
                                .multilineTextAlignment(.trailing)
                                .foregroundColor(.primaryBlue) // Highlight the rate
                        }
                    }
                }
                
                // MARK: - Save Action & Status Message
                Section {
                    if isLoading {
                        HStack {
                            Spacer()
                            ProgressView("Saving...") // Add text
                            Spacer()
                        }
                    } else {
                        Button("Save Changes") {
                            saveProfile()
                        }
                        .buttonStyle(.primaryDrivingApp)
                        .listRowBackground(Color.clear) // Make button fill width
                    }
                    
                    // Display status message (success or error)
                    if let msg = statusMessage {
                        Text(msg.text)
                            .font(.caption)
                            .foregroundColor(msg.isError ? .warningRed : .accentGreen)
                            .frame(maxWidth: .infinity, alignment: .center) // Center the message
                    }
                }
            }
            .navigationTitle("Edit Profile")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                // Load existing user data when the view appears
                loadUserData()
            }
            .sheet(isPresented: $isShowingAddressSearch) {
                // Sheet for address search
                AddressSearchView { selectedAddressString in
                    self.address = selectedAddressString
                }
            }
            // Refresh data if user object changes externally (e.g., after initial load)
            .onChange(of: authManager.user?.id) { _, _ in loadUserData() }
            .onChange(of: authManager.user?.photoURL) { _, _ in loadUserData() } // Refresh if photo URL changes
        }
    }
    
    // --- HELPER FUNCTIONS ---
    
    // Loads data from AuthManager into the @State variables
    func loadUserData() {
        guard let user = authManager.user else {
            print("ProfileView: Cannot load data, AuthManager user is nil.")
            return
        }
        print("ProfileView: Loading user data for \(user.email)") // Added log
        self.name = user.name ?? ""
        self.phone = user.phone ?? ""
        self.address = user.address ?? ""
        // Reset temporary photo data when loading existing data
        self.selectedPhotoData = nil
        self.selectedPhotoItem = nil
        
        if isInstructor {
            self.drivingSchool = user.drivingSchool ?? ""
            self.hourlyRate = String(format: "%.2f", user.hourlyRate ?? 0.0)
        }
        print("ProfileView: User data loaded.") // Added log
    }
    
    // Saves the profile data using AuthManager
    func saveProfile() {
        print("ProfileView: Save button tapped.") // Added log
        isLoading = true
        statusMessage = nil // Clear previous message
        
        Task {
            do {
                print("ProfileView: Calling AuthManager.updateUserProfile...") // Added log
                try await authManager.updateUserProfile(
                    name: name,
                    phone: phone,
                    address: address,
                    drivingSchool: isInstructor ? drivingSchool : nil,
                    hourlyRate: isInstructor ? (Double(hourlyRate) ?? 0.0) : nil,
                    photoData: selectedPhotoData // Pass the temporary photo data
                )
                
                // Success
                print("ProfileView: AuthManager.updateUserProfile successful.") // Added log
                isLoading = false
                statusMessage = (text: "Profile updated successfully!", isError: false)
                // Clear temporary photo data AFTER successful save
                selectedPhotoData = nil
                selectedPhotoItem = nil
                
            } catch {
                // Handle error from AuthManager
                print("!!! ProfileView Save FAILED: \(error.localizedDescription)") // Enhanced log
                isLoading = false
                // Show specific error message
                statusMessage = (text: "Failed to update profile. \(error.localizedDescription)", isError: true)
            }
        }
    }
}
