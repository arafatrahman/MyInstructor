//
//  ProfileView.swift
//  MyInstructor
//
//  Created by Gemini
//

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
    @State private var selectedPhotoData: Data?
    
    // --- STATE FOR UI AND ACTIONS ---
    @State private var isShowingAddressSearch = false
    @State private var isLoading = false
    @State private var successMessage: String?
    
    var isInstructor: Bool {
        authManager.role == .instructor
    }
    
    var userEmail: String {
        authManager.user?.email ?? "email@notfound.com"
    }
    
    // This computed property decides which image to show:
    // 1. A newly selected image (from PhotosPicker)
    // 2. An existing image (from AuthManager's user.photoURL)
    // 3. A placeholder
    @ViewBuilder
    private var profileImageView: some View {
        if let photoData = selectedPhotoData, let uiImage = UIImage(data: photoData) {
            // 1. Show newly selected image
            Image(uiImage: uiImage)
                .resizable()
                .scaledToFill()
                .frame(width: 120, height: 120)
                .clipShape(Circle())
                .overlay(Circle().stroke(Color.primaryBlue, lineWidth: 3))
        } else if let photoURLString = authManager.user?.photoURL, let url = URL(string: photoURLString) {
            // 2. Show existing remote image (NOTE: AsyncImage is iOS 15+)
            AsyncImage(url: url) { image in
                image
                    .resizable()
                    .scaledToFill()
                    .frame(width: 120, height: 120)
                    .clipShape(Circle())
            } placeholder: {
                ProgressView()
                    .frame(width: 120, height: 120)
            }
        } else {
            // 3. Show placeholder
            Image(systemName: "person.circle.fill")
                .resizable()
                .frame(width: 120, height: 120)
                .foregroundColor(.secondaryGray)
                .overlay(Circle().stroke(Color.textLight.opacity(0.3), lineWidth: 2))
        }
    }

    var body: some View {
        NavigationView {
            Form {
                // MARK: - Profile Photo Section
                Section {
                    VStack(spacing: 15) {
                        PhotosPicker(
                            selection: $selectedPhotoItem,
                            matching: .images,
                            photoLibrary: .shared()
                        ) {
                            profileImageView
                        }
                        .onChange(of: selectedPhotoItem) { newItem in
                            Task {
                                if let data = try? await newItem?.loadTransferable(type: Data.self) {
                                    selectedPhotoData = data
                                    successMessage = nil // Clear message on new photo
                                }
                            }
                        }
                        
                        // --- Redesigned Name and Edit Button ---
                        Text(name)
                            .font(.title2).bold()
                            .foregroundColor(.textDark)
                        
                        Text(userEmail)
                            .font(.subheadline)
                            .foregroundColor(.textLight)

                        PhotosPicker(
                            selection: $selectedPhotoItem,
                            matching: .images,
                            photoLibrary: .shared()
                        ) {
                            Text("Change Photo")
                                .font(.headline)
                                .foregroundColor(.primaryBlue)
                        }
                    }
                    .frame(maxWidth: .infinity)
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
                                .foregroundColor(address.isEmpty ? .textLight : .primaryBlue)
                            Text(address.isEmpty ? "Select Address" : address)
                                .foregroundColor(address.isEmpty ? .textLight : .textDark)
                                .lineLimit(2)
                        }
                        .padding(.vertical, 4) // Add padding for tap area
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
                                .foregroundColor(.primaryBlue)
                        }
                    }
                }
                
                // MARK: - Save Action
                Section {
                    if isLoading {
                        HStack {
                            Spacer()
                            ProgressView()
                            Spacer()
                        }
                    } else {
                        Button("Save Changes") {
                            saveProfile()
                        }
                        .buttonStyle(.primaryDrivingApp)
                        .listRowBackground(Color.clear)
                    }
                    
                    if let success = successMessage {
                        Text(success)
                            .font(.caption)
                            .foregroundColor(.accentGreen)
                    }
                }
            }
            .navigationTitle("Edit Profile")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                // Load existing data into the form
                loadUserData()
            }
            .sheet(isPresented: $isShowingAddressSearch) {
                AddressSearchView { selectedAddressString in
                    self.address = selectedAddressString
                }
            }
        }
    }
    
    // --- HELPER FUNCTIONS ---
    
    func loadUserData() {
        guard let user = authManager.user else { return }
        self.name = user.name ?? ""
        self.phone = user.phone ?? ""
        self.address = user.address ?? ""
        
        if isInstructor {
            self.drivingSchool = user.drivingSchool ?? ""
            // Ensure hourlyRate is formatted correctly from Double
            self.hourlyRate = String(format: "%.2f", user.hourlyRate ?? 0.0)
        }
    }
    
    func saveProfile() {
        isLoading = true
        successMessage = nil
        
        Task {
            do {
                // --- CORRECTED: Pass all state variables to the manager ---
                try await authManager.updateUserProfile(
                    name: name,
                    phone: phone,
                    address: address,
                    drivingSchool: isInstructor ? drivingSchool : nil,
                    hourlyRate: isInstructor ? (Double(hourlyRate) ?? 0.0) : nil,
                    photoData: selectedPhotoData
                )
                
                // Success
                isLoading = false
                successMessage = "Profile updated successfully!"
                selectedPhotoData = nil // Clear photo data after "save"
            } catch {
                // Handle error
                print("Error saving profile: \(error.localizedDescription)")
                isLoading = false
                successMessage = "Failed to update. Please try again."
            }
        }
    }
}
