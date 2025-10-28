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
    
    func fetchStudents(for instructorID: String) async throws -> [Student] {
        // TODO: Implement logic to find and return all students
        // associated with a specific instructor. This schema isn't
        // fully defined in the models. Returning empty.
        
        // This query assumes students have an 'instructorID' field,
        // which isn't on the 'Student' or 'AppUser' model.
        // A more likely schema is that an instructor has an array of student IDs.
        
        return []
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
