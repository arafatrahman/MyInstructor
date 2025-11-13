// File: arafatrahman/myinstructor/MyInstructor-main/MyInstructor/Core/Managers/DataService.swift
// --- UPDATED: Fixed 'AppAppUser' typo and added 'fetchInstructors' function ---

import Foundation
import Combine
import FirebaseFirestore

class DataService: ObservableObject {
    
    private let db = Firestore.firestore()
    private var usersCollection: CollectionReference {
        db.collection("users")
    }
    private var lessonsCollection: CollectionReference {
        db.collection("lessons")
    }
    
    // --- *** ADD THIS NEW COLLECTION REFERENCE *** ---
    private var offlineStudentsCollection: CollectionReference {
        db.collection("offline_students")
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
    
    /// Fetches all offline student records created by a specific instructor.
    func fetchOfflineStudents(for instructorID: String) async throws -> [OfflineStudent] {
        let snapshot = try await offlineStudentsCollection
            .whereField("instructorID", isEqualTo: instructorID)
            .order(by: "name") // Sort them alphabetically
            .getDocuments()
            
        let students = snapshot.documents.compactMap { document -> OfflineStudent? in
            try? document.data(as: OfflineStudent.self)
        }
        return students
    }
    // --- *** END OF NEW FUNCTION *** ---
    
    func fetchUser(withId userID: String) async throws -> AppUser? {
        let doc = try await usersCollection.document(userID).getDocument()
        return try doc.data(as: AppUser.self)
    }
    
    // --- *** THIS IS THE NEW FUNCTION *** ---
    // Fetches all the instructors a student is approved by
    func fetchInstructors(for studentID: String) async throws -> [AppUser] {
        // 1. Fetch the student's AppUser document
        let studentDoc = try await usersCollection.document(studentID).getDocument()
        guard let student = try? studentDoc.data(as: AppUser.self) else {
            print("Could not find student AppUser.")
            return []
        }
        
        // 2. Get the array of approved instructor IDs
        // We look for 'instructorIDs' which is on the AppUser model
        guard let instructorIDs = student.instructorIDs, !instructorIDs.isEmpty else {
            print("Student has no approved instructors.")
            return []
        }
        
        // 3. Fetch all user documents where the ID is in our instructorIDs array
        let instructorQuery = try await usersCollection
            .whereField(FieldPath.documentID(), in: instructorIDs)
            .getDocuments()
            
        // 4. Map the documents to AppUser objects
        // --- *** THIS IS THE TYPO FIX *** ---
        return instructorQuery.documents.compactMap { doc in
            try? doc.data(as: AppUser.self) // Was AppAppUser
        }
        // --- *** END OF FIX *** ---
    }
    // --- *** END OF NEW FUNCTION *** ---
    
    func getStudentName(for studentID: String) -> String {
        return "Unknown Student"
    }
}
