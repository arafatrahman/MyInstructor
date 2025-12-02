// File: arafatrahman/myinstructor/MyInstructor-main/MyInstructor/Core/Managers/LessonManager.swift
// --- UPDATED: Added updatePracticeSession function ---

import Foundation
import FirebaseFirestore
import Combine

class LessonManager: ObservableObject {
    private let db = Firestore.firestore()
    private var lessonsCollection: CollectionReference {
        db.collection("lessons")
    }
    
    // --- Practice Sessions Collection ---
    private var practiceCollection: CollectionReference {
        db.collection("practice_sessions")
    }

    // MARK: - Lesson Fetching
    func fetchLessons(for instructorID: String, start: Date, end: Date) async throws -> [Lesson] {
        let snapshot = try await lessonsCollection
            .whereField("instructorID", isEqualTo: instructorID)
            .getDocuments()
        let allLessons = snapshot.documents.compactMap { try? $0.data(as: Lesson.self) }
        return allLessons.filter { $0.startTime >= start && $0.startTime < end }
    }
    
    func fetchLessonsForStudent(studentID: String, start: Date, end: Date) async throws -> [Lesson] {
        let snapshot = try await lessonsCollection
            .whereField("studentID", isEqualTo: studentID)
            .getDocuments()
        let allLessons = snapshot.documents.compactMap { try? $0.data(as: Lesson.self) }
        return allLessons.filter { $0.startTime >= start && $0.startTime < end }
    }
    
    func fetchUpcomingLessons(for instructorID: String) async throws -> [Lesson] {
        let snapshot = try await lessonsCollection
            .whereField("instructorID", isEqualTo: instructorID)
            .whereField("status", isEqualTo: LessonStatus.scheduled.rawValue)
            .getDocuments()
        let allLessons = snapshot.documents.compactMap { try? $0.data(as: Lesson.self) }
        return allLessons.filter { $0.startTime > Date() }.sorted(by: { $0.startTime < $1.startTime })
    }
    
    func fetchLesson(id: String) async throws -> Lesson? {
        let document = try await lessonsCollection.document(id).getDocument()
        return try? document.data(as: Lesson.self)
    }

    // MARK: - Lesson CRUD
    func addLesson(newLesson: Lesson) async throws {
        let ref = try lessonsCollection.addDocument(from: newLesson)
        print("Lesson added successfully: \(newLesson.topic)")
        
        var lessonWithID = newLesson
        lessonWithID.id = ref.documentID
        NotificationManager.shared.scheduleLessonReminders(lesson: lessonWithID)
        
        // Notify Student
        let dateString = newLesson.startTime.formatted(date: .abbreviated, time: .shortened)
        NotificationManager.shared.sendNotification(
            to: newLesson.studentID,
            title: "New Lesson Scheduled",
            message: "A new lesson '\(newLesson.topic)' has been scheduled for \(dateString).",
            type: "lesson"
        )
    }
    
    func updateLesson(_ lesson: Lesson) async throws {
        guard let lessonID = lesson.id else {
            throw NSError(domain: "LessonManager", code: 0, userInfo: [NSLocalizedDescriptionKey: "Lesson ID missing."])
        }
        try lessonsCollection.document(lessonID).setData(from: lesson)
        NotificationManager.shared.scheduleLessonReminders(lesson: lesson)
        
        // Notify Student of Update
        let dateString = lesson.startTime.formatted(date: .abbreviated, time: .shortened)
        NotificationManager.shared.sendNotification(
            to: lesson.studentID,
            title: "Lesson Updated",
            message: "Your lesson '\(lesson.topic)' has been updated to \(dateString).",
            type: "lesson"
        )
    }

    func updateLessonStatus(lessonID: String, status: LessonStatus, initiatorID: String? = nil) async throws {
        // 1. Update Firestore
        try await lessonsCollection.document(lessonID).updateData([
            "status": status.rawValue
        ])
        
        // 2. Cleanup Local Reminders
        if status == .cancelled || status == .completed {
            NotificationManager.shared.cancelReminders(for: lessonID)
        }
        
        // 3. Send Cancellation Notification (If we know who initiated it)
        if status == .cancelled, let senderID = initiatorID {
            let document = try await lessonsCollection.document(lessonID).getDocument()
            if let lesson = try? document.data(as: Lesson.self) {
                let dateString = lesson.startTime.formatted(date: .abbreviated, time: .shortened)
                
                if senderID == lesson.studentID {
                    // Initiated by Student -> Notify Instructor
                    NotificationManager.shared.sendNotification(
                        to: lesson.instructorID,
                        title: "Lesson Cancelled",
                        message: "Student cancelled the lesson scheduled for \(dateString).",
                        type: "lesson"
                    )
                } else if senderID == lesson.instructorID {
                    // Initiated by Instructor -> Notify Student
                    NotificationManager.shared.sendNotification(
                        to: lesson.studentID,
                        title: "Lesson Cancelled",
                        message: "Your instructor cancelled the lesson scheduled for \(dateString).",
                        type: "lesson"
                    )
                }
            }
        }
    }
    
    // MARK: - Student Practice Logs & Notes
    
    func logPracticeSession(_ session: PracticeSession) async throws {
        try practiceCollection.addDocument(from: session)
        print("Practice session logged: \(session.durationHours) hours, Topic: \(session.topic ?? "None")")
    }
    
    // --- NEW: Update function ---
    func updatePracticeSession(_ session: PracticeSession) async throws {
        guard let id = session.id else { return }
        // setData overwrites the document with the new object data
        try practiceCollection.document(id).setData(from: session)
        print("Practice session updated.")
    }
    
    func fetchPracticeSessions(for studentID: String) async throws -> [PracticeSession] {
        let snapshot = try await practiceCollection
            .whereField("studentID", isEqualTo: studentID)
            .order(by: "date", descending: true)
            .getDocuments()
        
        return snapshot.documents.compactMap { try? $0.data(as: PracticeSession.self) }
    }
    
    func deletePracticeSession(id: String) async throws {
        try await practiceCollection.document(id).delete()
    }
}
