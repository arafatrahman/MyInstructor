// File: Features/UserManagement/AddOfflineStudentView.swift (New File)

import SwiftUI

struct AddOfflineStudentView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var authManager: AuthManager
    @EnvironmentObject var communityManager: CommunityManager
    
    var onStudentAdded: () -> Void // To trigger a refresh

    // --- *** ADDED NEW STATE *** ---
    @State private var name: String = ""
    @State private var phone: String = ""
    @State private var email: String = ""
    @State private var address: String = ""
    // --- *** ---
    
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
                    
                    // --- *** ADDED NEW FIELDS *** ---
                    TextField("Email (Optional)", text: $email)
                        .keyboardType(.emailAddress)
                        .autocapitalization(.none)
                    TextField("Address (Optional)", text: $address)
                    // --- *** ---
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
                                Text("Save Student")
                            }
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.primaryDrivingApp)
                    .disabled(!isFormValid || isLoading)
                    .listRowBackground(Color.clear)
                }
            }
            .navigationTitle("Add Offline Student")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
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
                // --- *** UPDATED FUNCTION CALL *** ---
                try await communityManager.addOfflineStudent(
                    instructorID: instructorID,
                    name: name.trimmingCharacters(in: .whitespacesAndNewlines),
                    phone: phone.isEmpty ? nil : phone.trimmingCharacters(in: .whitespacesAndNewlines),
                    email: email.isEmpty ? nil : email.trimmingCharacters(in: .whitespacesAndNewlines),
                    address: address.isEmpty ? nil : address.trimmingCharacters(in: .whitespacesAndNewlines)
                )
                // --- *** ---
                
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
