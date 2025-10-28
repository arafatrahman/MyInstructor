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
    
    // Updates the lesson status (e.g., completes a lesson)
    func updateLessonStatus(lessonID: String, status: LessonStatus) async throws {
        // Ensure we are updating the document by its ID
        try await lessonsCollection.document(lessonID).updateData([
            "status": status.rawValue
        ])
        print("Lesson \(lessonID) updated to \(status.rawValue)")
    }
}
