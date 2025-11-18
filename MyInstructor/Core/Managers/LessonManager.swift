// File: arafatrahman/myinstructor/MyInstructor-main/MyInstructor/Core/Managers/LessonManager.swift
// --- UPDATED: Added updateLesson function ---

import Foundation
import FirebaseFirestore
import Combine

class LessonManager: ObservableObject {
    private let db = Firestore.firestore()
    private var lessonsCollection: CollectionReference {
        db.collection("lessons")
    }

    // Fetches lessons for the current instructor within a specific date range
    func fetchLessons(for instructorID: String, start: Date, end: Date) async throws -> [Lesson] {
        let snapshot = try await lessonsCollection
            .whereField("instructorID", isEqualTo: instructorID)
            .whereField("startTime", isGreaterThanOrEqualTo: start)
            .whereField("startTime", isLessThan: end)
            .getDocuments()
            
        let lessons = snapshot.documents.compactMap { document in
            try? document.data(as: Lesson.self)
        }
        return lessons
    }

    // Creates a new lesson entry in Firestore
    func addLesson(newLesson: Lesson) async throws {
        try lessonsCollection.addDocument(from: newLesson)
        print("Lesson added successfully: \(newLesson.topic)")
    }
    
    // --- *** NEW FUNCTION TO SUPPORT EDITING *** ---
    /// Updates an existing lesson document in Firestore.
    func updateLesson(_ lesson: Lesson) async throws {
        guard let lessonID = lesson.id else {
            throw NSError(domain: "LessonManager", code: 0, userInfo: [NSLocalizedDescriptionKey: "Lesson ID missing, cannot update."])
        }
        
        // Use setData(from: lesson) on the specific document
        // This will overwrite the entire document with the new lesson data.
        try lessonsCollection.document(lessonID).setData(from: lesson)
        print("Lesson \(lessonID) updated successfully.")
    }

    
    // Updates the lesson status (e.g., completes a lesson)
    func updateLessonStatus(lessonID: String, status: LessonStatus) async throws {
        // Ensure we are updating the document by its ID
        try await lessonsCollection.document(lessonID).updateData([
            "status": status.rawValue
        ])
        print("Lesson \(lessonID) updated to \(status.rawValue)")
    }
}
