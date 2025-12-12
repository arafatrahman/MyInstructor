// File: arafatrahman/myinstructor/MyInstructor-main/MyInstructor/Core/Managers/LessonManager.swift
// --- UPDATED: Sends notification to the other party upon cancellation ---

import Foundation
import FirebaseFirestore
import Combine

class LessonManager: ObservableObject {
    private let db = Firestore.firestore()
    
    private var lessonsCollection: CollectionReference {
        db.collection("lessons")
    }
    
    private var practiceCollection: CollectionReference {
        db.collection("practice_sessions")
    }
    
    private var examsCollection: CollectionReference {
        db.collection("exam_results")
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
        var lessonToSave = newLesson
        lessonToSave.id = nil
        
        let ref = try lessonsCollection.addDocument(from: lessonToSave)
        
        var lessonWithID = newLesson
        lessonWithID.id = ref.documentID
        NotificationManager.shared.scheduleLessonReminders(lesson: lessonWithID)
        
        let dateString = newLesson.startTime.formatted(date: .abbreviated, time: .shortened)
        NotificationManager.shared.sendNotification(
            to: newLesson.studentID,
            title: "New Lesson Scheduled",
            message: "A new lesson '\(newLesson.topic)' has been scheduled for \(dateString).",
            type: "lesson",
            relatedID: ref.documentID
        )
    }
    
    func updateLesson(_ lesson: Lesson) async throws {
        guard let lessonID = lesson.id else { return }
        var lessonToSave = lesson
        lessonToSave.id = nil
        try lessonsCollection.document(lessonID).setData(from: lessonToSave)
        NotificationManager.shared.scheduleLessonReminders(lesson: lesson)
        
        let dateString = lesson.startTime.formatted(date: .abbreviated, time: .shortened)
        NotificationManager.shared.sendNotification(
            to: lesson.studentID,
            title: "Lesson Updated",
            message: "Your lesson '\(lesson.topic)' has been updated to \(dateString).",
            type: "lesson",
            relatedID: lessonID
        )
    }

    // --- UPDATED FUNCTION ---
    func updateLessonStatus(lessonID: String, status: LessonStatus, initiatorID: String? = nil) async throws {
        // 1. Update the status in Firestore
        try await lessonsCollection.document(lessonID).updateData(["status": status.rawValue])
        
        // 2. Handle Logic for Cancellation or Completion
        if status == .cancelled {
            // Cancel local reminders
            NotificationManager.shared.cancelReminders(for: lessonID)
            
            // Notify the other party if we know who initiated it
            if let initiatorID = initiatorID {
                // We need to fetch the lesson to know the other party's ID
                let doc = try await lessonsCollection.document(lessonID).getDocument()
                if let lesson = try? doc.data(as: Lesson.self) {
                    
                    var recipientID: String?
                    var message = ""
                    let dateStr = lesson.startTime.formatted(date: .abbreviated, time: .shortened)
                    
                    if initiatorID == lesson.instructorID {
                        // Instructor cancelled -> Notify Student
                        recipientID = lesson.studentID
                        message = "Your instructor has cancelled the lesson on \(dateStr)."
                    } else if initiatorID == lesson.studentID {
                        // Student cancelled -> Notify Instructor
                        recipientID = lesson.instructorID
                        message = "The student has cancelled the lesson on \(dateStr)."
                    }
                    
                    // Send the notification
                    if let toID = recipientID, !message.isEmpty {
                        NotificationManager.shared.sendNotification(
                            to: toID,
                            title: "Lesson Cancelled",
                            message: message,
                            type: "lesson", // Keeps using the lesson icon style
                            relatedID: lessonID
                        )
                    }
                }
            }
            
        } else if status == .completed {
            NotificationManager.shared.cancelReminders(for: lessonID)
        }
    }
    
    // MARK: - Practice Sessions
    
    func logPracticeSession(_ session: PracticeSession) async throws {
        var sessionToSave = session
        sessionToSave.id = nil
        try practiceCollection.addDocument(from: sessionToSave)
    }
    
    func updatePracticeSession(_ session: PracticeSession) async throws {
        guard let id = session.id else { return }
        var sessionToSave = session
        sessionToSave.id = nil
        try practiceCollection.document(id).setData(from: sessionToSave)
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
    
    // MARK: - Exam Results
    
    func logExamResult(_ exam: ExamResult) async throws {
        var data = exam
        data.id = nil
        try examsCollection.addDocument(from: data)
    }
    
    func updateExamResult(_ exam: ExamResult) async throws {
        guard let id = exam.id else { return }
        var data = exam
        data.id = nil
        try examsCollection.document(id).setData(from: data)
    }
    
    func fetchExamResults(for studentID: String) async throws -> [ExamResult] {
        let snapshot = try await examsCollection
            .whereField("studentID", isEqualTo: studentID)
            .order(by: "date", descending: true)
            .getDocuments()
        return snapshot.documents.compactMap { try? $0.data(as: ExamResult.self) }
    }
    
    func fetchExamsForInstructor(instructorID: String) async throws -> [ExamResult] {
        let snapshot = try await examsCollection
            .whereField("instructorID", isEqualTo: instructorID)
            .getDocuments()
        return snapshot.documents.compactMap { try? $0.data(as: ExamResult.self) }
    }
    
    func deleteExamResult(id: String) async throws {
        try await examsCollection.document(id).delete()
    }
}
