// File: arafatrahman/myinstructor/MyInstructor-main/MyInstructor/Features/UserManagement/OfflineStudentFormView.swift
// --- UPDATED: Wrapped in NavigationView to show Toolbar/Save button. Added Address Search. ---

import SwiftUI

struct OfflineStudentFormView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var authManager: AuthManager
    @EnvironmentObject var communityManager: CommunityManager
    
    let studentToEdit: OfflineStudent? // Pass in a student to edit
    var onStudentAdded: () -> Void // To trigger a refresh
    
    @State private var isEditing: Bool = false
    
    @State private var name: String = ""
    @State private var phone: String = ""
    @State private var email: String = ""
    @State private var address: String = ""
    
    @State private var isLoading = false
    @State private var errorMessage: String?
    
    // --- *** ADDED: State for Address Search *** ---
    @State private var isShowingAddressSearch = false
    
    private var isFormValid: Bool {
        !name.isEmpty
    }

    var body: some View {
        // --- *** ADDED: NavigationView wrapper is essential for Toolbar/Title to show in a Sheet *** ---
        NavigationView {
            Form {
                Section("Student Details") {
                    
                    // Name Input
                    HStack(spacing: 15) {
                        Image(systemName: "person.fill")
                            .foregroundColor(.primaryBlue)
                            .frame(width: 20)
                        Text("Name")
                        Spacer()
                        TextField("Full Name", text: $name)
                            .multilineTextAlignment(.trailing)
                    }
                    
                    // Phone Input
                    HStack(spacing: 15) {
                        Image(systemName: "phone.fill")
                            .foregroundColor(.primaryBlue)
                            .frame(width: 20)
                        Text("Phone")
                        Spacer()
                        TextField("Optional", text: $phone)
                            .keyboardType(.phonePad)
                            .multilineTextAlignment(.trailing)
                    }
                    
                    // Email Input
                    HStack(spacing: 15) {
                        Image(systemName: "envelope.fill")
                            .foregroundColor(.primaryBlue)
                            .frame(width: 20)
                        Text("Email")
                            .layoutPriority(1)
                        Spacer()
                        TextField("Optional", text: $email)
                            .keyboardType(.emailAddress)
                            .autocapitalization(.none)
                            .multilineTextAlignment(.trailing)
                    }
                    
                    // --- *** UPDATED: Address Field with Search *** ---
                    HStack(spacing: 15) {
                        Image(systemName: "mappin.and.ellipse")
                            .foregroundColor(.primaryBlue)
                            .frame(width: 20)
                        Text("Address")
                        Spacer()
                        
                        Button {
                            isShowingAddressSearch = true
                        } label: {
                            if address.isEmpty {
                                Text("Tap to search")
                                    .foregroundColor(Color(.placeholderText))
                            } else {
                                Text(address)
                                    .foregroundColor(.primary)
                                    .lineLimit(1)
                            }
                        }
                        .buttonStyle(.plain) // Removes default button highlighting
                    }
                }
                
                // Error Message Section
                if let error = errorMessage {
                    Section {
                        Text(error)
                            .foregroundColor(.warningRed)
                            .font(.caption)
                            .frame(maxWidth: .infinity, alignment: .center)
                    }
                    .listRowBackground(Color.clear)
                }
            }
            .navigationTitle(isEditing ? "Edit Student" : "Add Offline Student")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                // Cancel Button (Leading)
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                
                // Save Button (Trailing)
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        saveStudent()
                    } label: {
                        if isLoading {
                            ProgressView()
                        } else {
                            Text(isEditing ? "Save" : "Add")
                                .bold()
                        }
                    }
                    .disabled(!isFormValid || isLoading)
                }
            }
            .onAppear {
                if let student = studentToEdit {
                    isEditing = true
                    name = student.name
                    phone = student.phone ?? ""
                    email = student.email ?? ""
                    address = student.address ?? ""
                }
            }
            // --- *** ADDED: Address Search Sheet *** ---
            .sheet(isPresented: $isShowingAddressSearch) {
                AddressSearchView { selectedAddress in
                    self.address = selectedAddress
                }
            }
        }
    }
    
    private func saveStudent() {
        guard let instructorID = authManager.user?.id else {
            errorMessage = "Could not identify instructor."
            return
        }
        
        isLoading = true
        errorMessage = nil
        
        Task {
            do {
                let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
                let trimmedPhone = phone.trimmingCharacters(in: .whitespacesAndNewlines)
                let trimmedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)
                let trimmedAddress = address.trimmingCharacters(in: .whitespacesAndNewlines)
                
                if isEditing, let studentID = studentToEdit?.id {
                    // UPDATE
                    var updatedStudent = studentToEdit!
                    updatedStudent.name = trimmedName
                    updatedStudent.phone = trimmedPhone.isEmpty ? nil : trimmedPhone
                    updatedStudent.email = trimmedEmail.isEmpty ? nil : trimmedEmail
                    updatedStudent.address = trimmedAddress.isEmpty ? nil : trimmedAddress
                    
                    try await communityManager.updateOfflineStudent(updatedStudent)
                    
                } else {
                    // CREATE
                    try await communityManager.addOfflineStudent(
                        instructorID: instructorID,
                        name: trimmedName,
                        phone: trimmedPhone.isEmpty ? nil : trimmedPhone,
                        email: trimmedEmail.isEmpty ? nil : trimmedEmail,
                        address: trimmedAddress.isEmpty ? nil : trimmedAddress
                    )
                }
                
                onStudentAdded()
                dismiss()
                
            } catch {
                errorMessage = "Failed to save: \(error.localizedDescription)"
                isLoading = false
            }
        }
    }
}
