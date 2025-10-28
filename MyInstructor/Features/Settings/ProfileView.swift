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
                .multilineTextAlignment(.trailing) // Ensures TextField text is right-aligned
        }
        .padding(.vertical, 4)
    }
}
// --- End Helper View ---


struct ProfileView: View {
    @EnvironmentObject var authManager: AuthManager
    @Environment(\.dismiss) var dismiss // To potentially dismiss after save

    // --- State variables ---
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

    // --- Profile Data State ---
    @State private var aboutMe: String = ""
    @State private var education: [EducationEntry] = []
    @State private var expertise: [String] = []

    // For "Add" fields
    @State private var newEduTitle: String = ""
    @State private var newEduSubtitle: String = ""
    @State private var newEduYears: String = ""
    @State private var newSkill: String = ""

    // --- State for controlling add fields visibility ---
    @State private var isAddingEducation: Bool = false
    @State private var isAddingSkill: Bool = false
    // ---------------------------------------------------

    var isInstructor: Bool {
        authManager.role == .instructor
    }

    var userEmail: String {
        authManager.user?.email ?? "email@notfound.com"
    }

    // --- Profile Image ViewBuilder ---
    @ViewBuilder
    private var profileImageView: some View {
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
            .frame(width: 100, height: 100) // Ensure AsyncImage frame
            .background(Color.secondaryGray.opacity(0.3)) // Background for empty/failure
            .clipShape(Circle())

        }
        else {
            Image(systemName: "person.circle.fill")
                .resizable().scaledToFit()
                .frame(width: 100, height: 100).foregroundColor(.secondaryGray)
                .overlay(Circle().stroke(Color.textLight.opacity(0.3), lineWidth: 1))
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            Form {
                // MARK: - Profile Photo Section
                Section {
                    VStack(spacing: 8) {
                        profileImageView
                        PhotosPicker(selection: $selectedPhotoItem, matching: .images, photoLibrary: .shared()) {
                            Text("Change Photo")
                                .font(.caption).foregroundColor(.primaryBlue)
                        }
                        .onChange(of: selectedPhotoItem, handlePhotoSelection)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                }
                .listRowBackground(Color(.systemGroupedBackground))

                // MARK: - Personal Details Section
                Section("Personal Details") {
                    ProfileRow(iconName: "person.fill", label: "Name") {
                        TextField("Your full name", text: $name)
                    }
                    ProfileRow(iconName: "envelope.fill", label: "Email") {
                        Text(userEmail).foregroundColor(.textDark.opacity(0.7))
                    }
                    ProfileRow(iconName: "phone.fill", label: "Phone") {
                        TextField("Your phone number", text: $phone) .keyboardType(.phonePad)
                    }
                    ProfileRow(iconName: "location.fill", label: "Address") {
                        Button { isShowingAddressSearch = true } label: {
                            Text(address.isEmpty ? "Select Address" : address)
                                .foregroundColor(address.isEmpty ? Color(.placeholderText) : .textDark)
                                .lineLimit(2)
                                .frame(maxWidth: .infinity, alignment: .trailing)
                        }
                        .padding(.vertical, 5)
                    }
                }

                // MARK: - About Me Section
                Section("About Me") {
                    ZStack(alignment: .topLeading) {
                        TextEditor(text: $aboutMe)
                            .frame(minHeight: 100)
                            .padding(.top, -8)
                            .padding(.leading, -4)

                        if aboutMe.isEmpty {
                            Text("Write a short bio about your experience...")
                                .foregroundColor(Color(.placeholderText))
                                .padding(.top, 0)
                                .allowsHitTesting(false)
                        }
                    }
                }

                // MARK: - Education or Certification Section
                Section("Education or Certification") {
                    // Display existing entries
                    ForEach($education) { $entry in
                        VStack(alignment: .leading, spacing: 5) {
                            ProfileRow(iconName: "building.columns.fill", label: "Title") {
                                TextField("e.g., Stanford or ADI", text: $entry.title)
                            }
                            ProfileRow(iconName: "graduationcap.fill", label: "From") {
                                TextField("e.g., M.S. Maths or DVSA", text: $entry.subtitle)
                            }
                            ProfileRow(iconName: "calendar", label: "Year") {
                                TextField("e.g., 2020-2022 or Present", text: $entry.years)
                            }
                        }
                        .padding(.vertical, 6)
                    }
                    .onDelete { offsets in
                        education.remove(atOffsets: offsets)
                    }

                    // Conditionally show "Add New" fields
                    if isAddingEducation {
                        VStack(alignment: .leading, spacing: 8) {
                            ProfileRow(iconName: "building.columns.fill", label: "Title") {
                                TextField("New School / Cert Name", text: $newEduTitle)
                            }
                            ProfileRow(iconName: "graduationcap.fill", label: "From") {
                                TextField("New Degree / Body", text: $newEduSubtitle)
                            }
                            ProfileRow(iconName: "calendar", label: "Year") {
                                TextField("New Years Attended / Received", text: $newEduYears)
                            }
                        }
                        .padding(.top, 10)
                        .transition(.opacity.combined(with: .move(edge: .top))) // Add animation
                    }

                    // "Add / Confirm Add" Button
                    Button {
                        addEducationEntry() // Now toggles visibility or adds entry
                    } label: {
                        HStack {
                           Image(systemName: isAddingEducation ? "checkmark.circle.fill" : "plus.circle.fill")
                           Text(isAddingEducation ? "Confirm Entry" : "Add Education Entry")
                        }
                        .foregroundColor(.primaryBlue)
                    }
                    .frame(maxWidth: .infinity, alignment: .trailing)
                    .padding(.top, 5)

                }

                // MARK: - Instructor Section
                if isInstructor {
                    Section("Instructor Details") {
                        ProfileRow(iconName: "briefcase.fill", label: "School") {
                            TextField("Your driving school name", text: $drivingSchool)
                        }
                        ProfileRow(iconName: "creditcard.fill", label: "Rate (£)") {
                            TextField("e.g., 45.00", text: $hourlyRate)
                                .keyboardType(.decimalPad)
                                .foregroundColor(.primaryBlue)
                        }
                    }

                    // MARK: - Expertise Section
                    Section("Expertise (Skills)") {
                        ForEach(expertise, id: \.self) { skill in
                            HStack {
                                Text(skill)
                                Spacer()
                            }
                        }
                        .onDelete { offsets in
                            expertise.remove(atOffsets: offsets)
                        }

                        // Conditionally show "Add New" field
                        if isAddingSkill {
                            ProfileRow(iconName: "plus.circle.fill", label: "New Skill") {
                                 TextField("e.g., Nervous Drivers, Parking", text: $newSkill)
                                    .onSubmit { addSkill() } // Keep onSubmit
                            }
                            .transition(.opacity.combined(with: .move(edge: .top))) // Add animation
                        }

                        // "Add / Confirm Add" Button for Skills
                        Button {
                            addSkill() // Now toggles visibility or adds skill
                        } label: {
                             HStack {
                                Image(systemName: isAddingSkill ? "checkmark.circle.fill" : "plus.circle.fill")
                                Text(isAddingSkill ? "Confirm Skill" : "Add Skill")
                             }
                             .foregroundColor(.primaryBlue)
                        }
                        .frame(maxWidth: .infinity, alignment: .trailing)
                        .padding(.top, 5)

                    }
                }

            } // End Form

            // Status Message Display Area
            if let msg = statusMessage {
                Text(msg.text)
                    .font(.caption)
                    .foregroundColor(msg.isError ? .warningRed : .accentGreen)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.horizontal)
                    .padding(.vertical, 5)
                    .background(Color(.systemGroupedBackground))
            }

        } // End VStack
        .navigationTitle("Edit Profile")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            // Save Button in Toolbar
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    saveProfile()
                } label: {
                    if isLoading {
                        ProgressView()
                            .tint(Color.primaryBlue)
                    } else {
                        Text("Save")
                            .bold()
                            .foregroundColor(Color.primaryBlue)
                    }
                }
                .disabled(isLoading)
            }
        }
        .animation(.default, value: isAddingEducation) // Animate changes
        .animation(.default, value: isAddingSkill)     // Animate changes
        .onAppear(perform: loadUserData)
        .sheet(isPresented: $isShowingAddressSearch) {
            AddressSearchView { selectedAddressString in self.address = selectedAddressString }
        }
        .onChange(of: authManager.user?.id) { _, _ in loadUserData() }
        .onChange(of: authManager.user?.photoURL) { _, _ in loadUserData() }
        .applyAppTheme()
    }

    // --- HELPER FUNCTIONS ---

    func handlePhotoSelection(oldItem: PhotosPickerItem?, newItem: PhotosPickerItem?) {
         Task {
            statusMessage = nil
            selectedPhotoData = nil
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
        self.aboutMe = user.aboutMe ?? ""
        self.education = user.education ?? []

        if isInstructor {
            self.drivingSchool = user.drivingSchool ?? ""
            self.hourlyRate = String(format: "%.2f", user.hourlyRate ?? 0.0)
            self.expertise = user.expertise ?? []
        }

        // Reset add fields and visibility state when loading
        self.newEduTitle = ""
        self.newEduSubtitle = ""
        self.newEduYears = ""
        self.newSkill = ""
        self.isAddingEducation = false
        self.isAddingSkill = false

        print("ProfileView: User data loaded.")
    }

    // Add Education Function (Toggles visibility or adds entry)
    func addEducationEntry() {
        if isAddingEducation {
            // Fields are visible, try to add the entry
            let trimmedTitle = newEduTitle.trimmingCharacters(in: .whitespacesAndNewlines)
            let trimmedSubtitle = newEduSubtitle.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmedTitle.isEmpty && !trimmedSubtitle.isEmpty {
                education.append(EducationEntry(title: trimmedTitle, subtitle: trimmedSubtitle, years: newEduYears.trimmingCharacters(in: .whitespacesAndNewlines)))
                // Clear fields after adding
                newEduTitle = ""
                newEduSubtitle = ""
                newEduYears = ""
                isAddingEducation = false // Hide fields after adding
            } else {
                 statusMessage = (text: "Title and From fields cannot be empty.", isError: true)
            }
        } else {
            // Fields are hidden, just show them
            isAddingEducation = true
            statusMessage = nil
        }
    }

    // Add Skill Function (Toggles visibility or adds skill)
    func addSkill() {
        if isAddingSkill {
            // Fields are visible, try to add the skill
            let trimmedSkill = newSkill.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmedSkill.isEmpty {
                if !expertise.contains(where: { $0.caseInsensitiveCompare(trimmedSkill) == .orderedSame }) {
                     expertise.append(trimmedSkill)
                }
                newSkill = ""
                isAddingSkill = false // Hide field after adding
            } else {
                statusMessage = (text: "Skill field cannot be empty.", isError: true)
            }
        } else {
            // Field is hidden, just show it
            isAddingSkill = true
             statusMessage = nil
        }
    }


    // Save Profile Function (No longer adds pending items)
    func saveProfile() {
        print("ProfileView: Save button tapped.")

        // Hide any currently shown 'Add New' fields before saving
        if isAddingEducation {
            isAddingEducation = false
            // Clear fields - user must click Confirm first
             newEduTitle = ""
             newEduSubtitle = ""
             newEduYears = ""
        }
        if isAddingSkill {
            isAddingSkill = false
            newSkill = ""
        }

        isLoading = true
        statusMessage = nil

        // Use the current state of education and expertise arrays
        let finalEducation = education
        let finalExpertise = expertise

        Task {
            do {
                print("ProfileView: Calling AuthManager.updateUserProfile...")
                try await authManager.updateUserProfile(
                    name: name,
                    phone: phone,
                    address: address,
                    drivingSchool: isInstructor ? drivingSchool : nil,
                    hourlyRate: isInstructor ? (Double(hourlyRate) ?? 0.0) : nil,
                    photoData: selectedPhotoData,
                    aboutMe: aboutMe,
                    education: finalEducation,
                    expertise: isInstructor ? finalExpertise : nil
                )

                print("ProfileView: AuthManager.updateUserProfile successful.")
                isLoading = false
                statusMessage = (text: "Profile updated successfully!", isError: false)
                selectedPhotoData = nil
                selectedPhotoItem = nil

                // Clear "Add New" fields just in case
                newEduTitle = ""
                newEduSubtitle = ""
                newEduYears = ""
                newSkill = ""

                // Optionally dismiss after save
                // dismiss()

            } catch {
                print("!!! ProfileView Save FAILED: \(error.localizedDescription)")
                isLoading = false
                statusMessage = (text: "Failed to update profile. \(error.localizedDescription)", isError: true)
            }
        }
    }
}
