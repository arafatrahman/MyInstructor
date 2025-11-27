// File: arafatrahman/myinstructor/MyInstructor-main/MyInstructor/Core/Managers/LessonManager.swift
// --- UPDATED: Added fetchUpcomingLessons function ---

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
    
    // --- NEW: Fetch ALL upcoming scheduled lessons (Future Income) ---
    func fetchUpcomingLessons(for instructorID: String) async throws -> [Lesson] {
        let snapshot = try await lessonsCollection
            .whereField("instructorID", isEqualTo: instructorID)
            .whereField("status", isEqualTo: LessonStatus.scheduled.rawValue)
            .whereField("startTime", isGreaterThan: Date()) // Only future lessons
            .order(by: "startTime")
            .getDocuments()
            
        return snapshot.documents.compactMap { try? $0.data(as: Lesson.self) }
    }

    // Creates a new lesson entry in Firestore
    func addLesson(newLesson: Lesson) async throws {
        try lessonsCollection.addDocument(from: newLesson)
        print("Lesson added successfully: \(newLesson.topic)")
    }
    
    // Updates an existing lesson document in Firestore.
    func updateLesson(_ lesson: Lesson) async throws {
        guard let lessonID = lesson.id else {
            throw NSError(domain: "LessonManager", code: 0, userInfo: [NSLocalizedDescriptionKey: "Lesson ID missing, cannot update."])
        }
        try lessonsCollection.document(lessonID).setData(from: lesson)
        print("Lesson \(lessonID) updated successfully.")
    }

    // Updates the lesson status (e.g., completes a lesson)
    func updateLessonStatus(lessonID: String, status: LessonStatus) async throws {
        try await lessonsCollection.document(lessonID).updateData([
            "status": status.rawValue
        ])
        print("Lesson \(lessonID) updated to \(status.rawValue)")
    }
}
