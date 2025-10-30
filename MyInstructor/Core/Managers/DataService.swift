// File: arafatrahman/myinstructor/MyInstructor-main/MyInstructor/Core/Managers/DataService.swift
// --- UPDATED with new fetchUser function ---

import Foundation
import Combine
import FirebaseFirestore

/*
 DataService acts as the common interface for fetching and providing data.
 It needs to be populated with real data-fetching logic.
 */
class DataService: ObservableObject {
    
    private let db = Firestore.firestore()
    private var usersCollection: CollectionReference {
        db.collection("users")
    }
    private var lessonsCollection: CollectionReference {
        db.collection("lessons")
    }
    
    init() {
        // Initialization is now empty
    }
    
    // MARK: - Dashboard Data Fetching
    
    func fetchInstructorDashboardData(for instructorID: String) async throws -> (nextLesson: Lesson?, earnings: Double, avgProgress: Double) {
        let lessonSnapshot = try await lessonsCollection
            .whereField("instructorID", isEqualTo: instructorID)
            .whereField("status", isEqualTo: LessonStatus.scheduled.rawValue)
            .whereField("startTime", isGreaterThan: Date())
            .order(by: "startTime")
            .limit(to: 1)
            .getDocuments()
            
        let nextLesson = try? lessonSnapshot.documents.first?.data(as: Lesson.self)
        
        // Placeholder return values
        return (nextLesson, 0.0, 0.0)
    }

    func fetchStudentDashboardData(for studentID: String) async throws -> (upcomingLesson: Lesson?, progress: Double, latestFeedback: String, paymentDue: Bool) {
        let lessonSnapshot = try await lessonsCollection
            .whereField("studentID", isEqualTo: studentID)
            .whereField("status", isEqualTo: LessonStatus.scheduled.rawValue)
            .whereField("startTime", isGreaterThan: Date())
            .order(by: "startTime")
            .limit(to: 1)
            .getDocuments()
            
        let upcomingLesson = try? lessonSnapshot.documents.first?.data(as: Lesson.self)
        
        // Placeholder return values
        return (upcomingLesson, 0.0, "", false)
    }
    
    // MARK: - User Management Fetching
    
    func fetchStudents(for instructorID: String) async throws -> [Student] {
        let instructorDoc = try await usersCollection.document(instructorID).getDocument()
        guard let instructor = try? instructorDoc.data(as: AppUser.self) else {
            print("Could not find instructor AppUser.")
            return []
        }
        
        guard let studentIDs = instructor.studentIDs, !studentIDs.isEmpty else {
            print("Instructor has no approved students.")
            return []
        }
        
        let studentQuery = try await usersCollection
            .whereField(FieldPath.documentID(), in: studentIDs)
            .getDocuments()
            
        let students = studentQuery.documents.compactMap { document -> Student? in
            guard let appUser = try? document.data(as: AppUser.self) else { return nil }
            
            return Student(
                id: appUser.id,
                userID: appUser.id ?? "unknown_user_id",
                name: appUser.name ?? "Student",
                photoURL: appUser.photoURL,
                email: appUser.email,
                drivingSchool: appUser.drivingSchool
            )
        }
        
        return students
    }
    
    // --- *** ADD THIS NEW FUNCTION *** ---
    // Fetches a single AppUser by their ID
    func fetchUser(withId userID: String) async throws -> AppUser? {
        let doc = try await usersCollection.document(userID).getDocument()
        return try doc.data(as: AppUser.self)
    }
    
    // Fetches a specific user's public data (like name)
    func getStudentName(for studentID: String) -> String {
        // This function was synchronous and relied on a mock cache.
        // It should be replaced with an async function.
        return "Unknown Student"
    }
}
