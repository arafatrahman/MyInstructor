// File: Features/UserManagement/OfflineStudentFormView.swift (Renamed from AddOfflineStudentView.swift)

import SwiftUI

struct OfflineStudentFormView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var authManager: AuthManager
    @EnvironmentObject var communityManager: CommunityManager
    
    // --- *** ADDED/MODIFIED *** ---
    let studentToEdit: OfflineStudent? // Pass in a student to edit
    var onStudentAdded: () -> Void // To trigger a refresh
    
    @State private var isEditing: Bool = false
    // --- *** ---
    
    @State private var name: String = ""
    @State private var phone: String = ""
    @State private var email: String = ""
    @State private var address: String = ""
    
    @State private var isLoading = false
    @State private var errorMessage: String?
    
    private var isFormValid: Bool {
        !name.isEmpty
    }

    var body: some View {
        NavigationView {
            Form {
                Section("Student Details") {
                    TextField("Student's Full Name", text: $name)
                    TextField("Phone Number (Optional)", text: $phone)
                        .keyboardType(.phonePad)
                    TextField("Email (Optional)", text: $email)
                        .keyboardType(.emailAddress)
                        .autocapitalization(.none)
                    TextField("Address (Optional)", text: $address)
                }
                
                Section {
                    if let error = errorMessage {
                        Text(error).foregroundColor(.warningRed)
                    }
                    
                    Button {
                        saveStudent()
                    } label: {
                        HStack {
                            if isLoading {
                                ProgressView().tint(.white)
                            } else {
                                // --- *** MODIFIED *** ---
                                Text(isEditing ? "Save Changes" : "Save Student")
                            }
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.primaryDrivingApp)
                    .disabled(!isFormValid || isLoading)
                    .listRowBackground(Color.clear)
                }
            }
            // --- *** MODIFIED *** ---
            .navigationTitle(isEditing ? "Edit Student" : "Add Offline Student")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                }
            }
            // --- *** ADDED THIS MODIFIER *** ---
            .onAppear {
                // If we are editing, populate the fields
                if let student = studentToEdit {
                    isEditing = true
                    name = student.name
                    phone = student.phone ?? ""
                    email = student.email ?? ""
                    address = student.address ?? ""
                }
            }
        }
    }
    
    // --- *** THIS FUNCTION IS UPDATED *** ---
    private func saveStudent() {
        guard let instructorID = authManager.user?.id else {
            errorMessage = "Could not identify instructor."
            return
        }
        
        isLoading = true
        errorMessage = nil
        
        Task {
            do {
                if isEditing, let studentID = studentToEdit?.id {
                    // This is an UPDATE
                    var updatedStudent = studentToEdit!
                    updatedStudent.name = name.trimmingCharacters(in: .whitespacesAndNewlines)
                    updatedStudent.phone = phone.isEmpty ? nil : phone.trimmingCharacters(in: .whitespacesAndNewlines)
                    updatedStudent.email = email.isEmpty ? nil : email.trimmingCharacters(in: .whitespacesAndNewlines)
                    updatedStudent.address = address.isEmpty ? nil : address.trimmingCharacters(in: .whitespacesAndNewlines)
                    
                    try await communityManager.updateOfflineStudent(updatedStudent)
                    
                } else {
                    // This is a CREATE
                    try await communityManager.addOfflineStudent(
                        instructorID: instructorID,
                        name: name.trimmingCharacters(in: .whitespacesAndNewlines),
                        phone: phone.isEmpty ? nil : phone.trimmingCharacters(in: .whitespacesAndNewlines),
                        email: email.isEmpty ? nil : email.trimmingCharacters(in: .whitespacesAndNewlines),
                        address: address.isEmpty ? nil : address.trimmingCharacters(in: .whitespacesAndNewlines)
                    )
                }
                
                // Success!
                onStudentAdded() // Call the refresh handler
                dismiss() // Close the sheet
                
            } catch {
                errorMessage = "Failed to save student: \(error.localizedDescription)"
                isLoading = false
            }
        }
    }
}
