// File: arafatrahman/myinstructor/MyInstructor-main/MyInstructor/Core/Managers/LessonManager.swift
// --- UPDATED: Fetches student name for notifications and uses updated NotificationManager signature ---

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
    
    // MARK: - Helper
    private func fetchStudentName(studentID: String) async -> String {
        // Try Offline Student
        if let doc = try? await db.collection("offline_students").document(studentID).getDocument(),
           let student = try? doc.data(as: OfflineStudent.self) {
            return student.name
        }
        
        // Try App User (Real Student)
        if let doc = try? await db.collection("users").document(studentID).getDocument(),
           let user = try? doc.data(as: AppUser.self) {
            return user.name ?? "Student"
        }
        
        return "Student"
    }

    // MARK: - Lesson CRUD
    func addLesson(newLesson: Lesson) async throws {
        var lessonToSave = newLesson
        lessonToSave.id = nil
        
        let ref = try lessonsCollection.addDocument(from: lessonToSave)
        
        var lessonWithID = newLesson
        lessonWithID.id = ref.documentID
        
        // --- UPDATED: Fetch name and pass to scheduler ---
        let studentName = await fetchStudentName(studentID: newLesson.studentID)
        NotificationManager.shared.scheduleLessonReminders(lesson: lessonWithID, studentName: studentName)
        
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
        
        // --- UPDATED: Fetch name and pass to scheduler ---
        let studentName = await fetchStudentName(studentID: lesson.studentID)
        NotificationManager.shared.scheduleLessonReminders(lesson: lesson, studentName: studentName)
        
        let dateString = lesson.startTime.formatted(date: .abbreviated, time: .shortened)
        NotificationManager.shared.sendNotification(
            to: lesson.studentID,
            title: "Lesson Updated",
            message: "Your lesson '\(lesson.topic)' has been updated to \(dateString).",
            type: "lesson",
            relatedID: lessonID
        )
    }

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
                        // --- UPDATED: Use actual student name ---
                        let studentName = await fetchStudentName(studentID: lesson.studentID)
                        message = "\(studentName) has cancelled the lesson on \(dateStr)."
                    }
                    
                    // Send the notification
                    if let toID = recipientID, !message.isEmpty {
                        NotificationManager.shared.sendNotification(
                            to: toID,
                            title: "Lesson Cancelled",
                            message: message,
                            type: "lesson",
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
    
    // MARK: - Exam Results (Updated for Notifications)
    
    func logExamResult(_ exam: ExamResult, initiatorID: String) async throws {
        var data = exam
        data.id = nil
        let ref = try examsCollection.addDocument(from: data)
        
        let dateStr = exam.date.formatted(date: .abbreviated, time: .shortened)
        notifyExamParty(exam: exam, initiatorID: initiatorID, title: "Exam Scheduled", message: "A new driving exam at \(exam.testCenter) has been scheduled for \(dateStr).", relatedID: ref.documentID)
    }
    
    func updateExamResult(_ exam: ExamResult, initiatorID: String) async throws {
        guard let id = exam.id else { return }
        var data = exam
        data.id = nil
        try examsCollection.document(id).setData(from: data)
        
        let dateStr = exam.date.formatted(date: .abbreviated, time: .shortened)
        notifyExamParty(exam: exam, initiatorID: initiatorID, title: "Exam Updated", message: "The driving exam at \(exam.testCenter) on \(dateStr) has been updated.", relatedID: id)
    }
    
    func deleteExamResult(id: String, initiatorID: String) async throws {
        // Fetch first to get details for notification
        let doc = try await examsCollection.document(id).getDocument()
        if let exam = try? doc.data(as: ExamResult.self) {
            try await examsCollection.document(id).delete()
            
            let dateStr = exam.date.formatted(date: .abbreviated, time: .shortened)
            notifyExamParty(exam: exam, initiatorID: initiatorID, title: "Exam Cancelled", message: "The driving exam at \(exam.testCenter) on \(dateStr) has been cancelled.", relatedID: nil)
        } else {
            // Just delete if we can't read it
            try await examsCollection.document(id).delete()
        }
    }
    
    // --- Helper for Exam Notifications ---
    private func notifyExamParty(exam: ExamResult, initiatorID: String, title: String, message: String, relatedID: String?) {
        var recipientID: String?
        
        if initiatorID == exam.studentID {
            // Student performed the action -> Notify Instructor
            recipientID = exam.instructorID
        } else if initiatorID == exam.instructorID {
            // Instructor performed the action -> Notify Student
            recipientID = exam.studentID
        }
        
        if let toID = recipientID, !toID.isEmpty {
            NotificationManager.shared.sendNotification(
                to: toID,
                title: title,
                message: message,
                type: "exam", // Used in NotificationsView for custom icon
                relatedID: relatedID
            )
        }
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
}
