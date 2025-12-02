// File: MyInstructor/Core/Managers/PersonalEventManager.swift
import Foundation
import FirebaseFirestore
import Combine

class PersonalEventManager: ObservableObject {
    private let db = Firestore.firestore()
    private var eventsCollection: CollectionReference {
        db.collection("personal_events")
    }
    
    // MARK: - CRUD
    
    func addEvent(_ event: PersonalEvent) async throws {
        // Create a copy and set id to nil to suppress @DocumentID warning
        var eventToSave = event
        eventToSave.id = nil
        try eventsCollection.addDocument(from: eventToSave)
    }
    
    func updateEvent(_ event: PersonalEvent) async throws {
        guard let id = event.id else { return }
        
        // Create a copy and set id to nil to suppress @DocumentID warning
        var eventToSave = event
        eventToSave.id = nil
        
        try eventsCollection.document(id).setData(from: eventToSave)
    }
    
    func deleteEvent(id: String) async throws {
        try await eventsCollection.document(id).delete()
    }
    
    // MARK: - Fetching
    
    func fetchEvents(for userID: String, start: Date, end: Date) async throws -> [PersonalEvent] {
        let snapshot = try await eventsCollection
            .whereField("userID", isEqualTo: userID)
            .getDocuments()
        
        let allEvents = snapshot.documents.compactMap { try? $0.data(as: PersonalEvent.self) }
        
        // Filter by date range locally
        return allEvents.filter { $0.date >= start && $0.date < end }
    }
}
