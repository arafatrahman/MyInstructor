// File: arafatrahman/myinstructor/MyInstructor-main/MyInstructor/Core/Managers/ContactManager.swift
import Foundation
import FirebaseFirestore
import Combine

class ContactManager: ObservableObject {
    private let db = Firestore.firestore()
    
    // Fetch custom contacts for a specific instructor
    func fetchCustomContacts(for instructorID: String) async throws -> [CustomContact] {
        let snapshot = try await db.collection("users")
            .document(instructorID)
            .collection("custom_contacts")
            .order(by: "name")
            .getDocuments()
        
        return snapshot.documents.compactMap { try? $0.data(as: CustomContact.self) }
    }
    
    // Add a new custom contact
    func addContact(_ contact: CustomContact) async throws {
        var contactToSave = contact
        contactToSave.id = nil // Ensure ID is nil so Firestore generates one
        try db.collection("users")
            .document(contact.instructorID)
            .collection("custom_contacts")
            .addDocument(from: contactToSave)
    }
    
    // Update an existing custom contact
    func updateContact(_ contact: CustomContact) async throws {
        guard let contactID = contact.id else { return }
        var contactToSave = contact
        contactToSave.id = nil // Remove ID from data payload
        
        try db.collection("users")
            .document(contact.instructorID)
            .collection("custom_contacts")
            .document(contactID)
            .setData(from: contactToSave)
    }
    
    // Delete a custom contact
    func deleteContact(contactID: String, instructorID: String) async throws {
        try await db.collection("users")
            .document(instructorID)
            .collection("custom_contacts")
            .document(contactID)
            .delete()
    }
}
