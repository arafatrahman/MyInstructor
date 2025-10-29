// File: arafatrahman/myinstructor/MyInstructor-main/MyInstructor/Core/Managers/DataService.swift
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
        // TODO: Implement logic to fetch next lesson, calculate weekly earnings,
        // and calculate average student progress for the given instructor.
        
        // Example for fetching next lesson (untested)
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
        // TODO: Implement logic to fetch upcoming lesson, current progress,
        // latest feedback, and payment status for the given student.
        
        // Example for fetching upcoming lesson (untested)
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
    
    // --- *** THIS IS THE UPDATED/FIXED FUNCTION *** ---
    func fetchStudents(for instructorID: String) async throws -> [Student] {
        // 1. Fetch the instructor's AppUser document first
        let instructorDoc = try await usersCollection.document(instructorID).getDocument()
        guard let instructor = try? instructorDoc.data(as: AppUser.self) else {
            print("Could not find instructor AppUser.")
            return []
        }
        
        // 2. Get the array of approved student IDs
        guard let studentIDs = instructor.studentIDs, !studentIDs.isEmpty else {
            print("Instructor has no approved students.")
            return []
        }
        
        // 3. Fetch all user documents where the ID is in our studentIDs array
        // NOTE: Firestore 'in' queries are limited to 30 items.
        // For > 30 students, you would need multiple queries.
        let studentQuery = try await usersCollection
            .whereField(FieldPath.documentID(), in: studentIDs)
            .getDocuments()
            
        // 4. Map the AppUser data to the 'Student' model, as your app expects
        let students = studentQuery.documents.compactMap { document -> Student? in
            guard let appUser = try? document.data(as: AppUser.self) else { return nil }
            
            // This maps AppUser data to the Student model for your lists
            return Student(
                id: appUser.id,
                userID: appUser.id ?? "unknown_user_id",
                name: appUser.name ?? "Student",
                photoURL: appUser.photoURL,
                email: appUser.email,
                drivingSchool: appUser.drivingSchool
                // Note: averageProgress etc. are on the Student model
                // but not AppUser. This data would need to be populated
                // from a different source (e.g., a 'progress' collection).
                // For now, it will default to 0.0.
            )
        }
        
        return students
    }
    
    // Fetches a specific user's public data (like name)
    func getStudentName(for studentID: String) -> String {
        // This function was synchronous and relied on a mock cache.
        // It should be replaced with an async function that fetches
        // the user's name from Firestore when needed.
        
        // For now, it returns a placeholder.
        return "Unknown Student"
        
        // A real implementation would look like:
        // func getUser(id: String) async throws -> AppUser? {
        //     try await usersCollection.document(id).getDocument(as: AppUser.self)
        // }
        // ...and views would call this async function.
    }
}
