// File: arafatrahman/myinstructor/MyInstructor-main/MyInstructor/Features/Contacts/AddContactFormView.swift
import SwiftUI

struct AddContactFormView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var contactManager: ContactManager
    @EnvironmentObject var authManager: AuthManager
    
    var contactToEdit: CustomContact?
    var onSave: () -> Void
    
    @State private var name: String = ""
    @State private var phone: String = ""
    @State private var email: String = ""
    @State private var note: String = ""
    @State private var isLoading = false
    @State private var errorMessage: String?
    
    var isEditing: Bool { contactToEdit != nil }
    
    var body: some View {
        NavigationView {
            Form {
                Section("Contact Details") {
                    TextField("Full Name", text: $name)
                        .textContentType(.name)
                    
                    TextField("Phone Number", text: $phone)
                        .keyboardType(.phonePad)
                        .textContentType(.telephoneNumber)
                    
                    TextField("Email (Optional)", text: $email)
                        .keyboardType(.emailAddress)
                        .autocapitalization(.none)
                }
                
                Section("Notes") {
                    TextField("Add a note...", text: $note)
                }
                
                if let error = errorMessage {
                    Section {
                        Text(error).foregroundColor(.warningRed).font(.caption)
                    }
                }
            }
            .navigationTitle(isEditing ? "Edit Contact" : "Add Contact")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveContact()
                    }
                    .bold()
                    .disabled(name.isEmpty || phone.isEmpty || isLoading)
                }
            }
            .onAppear {
                if let c = contactToEdit {
                    name = c.name
                    phone = c.phone
                    email = c.email ?? ""
                    note = c.note ?? ""
                }
            }
        }
    }
    
    private func saveContact() {
        guard let instructorID = authManager.user?.id else { return }
        isLoading = true
        
        let contact = CustomContact(
            id: contactToEdit?.id,
            instructorID: instructorID,
            name: name,
            phone: phone,
            email: email.isEmpty ? nil : email,
            note: note.isEmpty ? nil : note
        )
        
        Task {
            do {
                if isEditing {
                    try await contactManager.updateContact(contact)
                } else {
                    try await contactManager.addContact(contact)
                }
                onSave()
                dismiss()
            } catch {
                errorMessage = "Failed to save: \(error.localizedDescription)"
            }
            isLoading = false
        }
    }
}
