import Foundation
import FirebaseFirestore
import Combine // Added Combine for ObservableObject

class LessonManager: ObservableObject {
    private let db = Firestore.firestore()
    private let lessonsCollection = "lessons"
    
    // EXPOSED PUBLICLY for mock data access/filtering by views (like StudentProfileView)
    @Published public var publicMockLessons: [Lesson] = [
        // Dummy data for demonstration purposes
        Lesson(instructorID: "i_auth_id", studentID: "student_abc", topic: "Manoeuvres: Parking", startTime: Date().addingTimeInterval(3600*2), duration: 5400, pickupLocation: "10 Downing St", fee: 45.00),
        Lesson(instructorID: "i_auth_id", studentID: "student_abc", topic: "Junctions", startTime: Date().addingTimeInterval(-3600*12), duration: 3600, pickupLocation: "High Street", fee: 40.00, status: .completed),
        Lesson(instructorID: "i_auth_id", studentID: "student_xyz", topic: "Basic Controls", startTime: Date().addingTimeInterval(-3600*48), duration: 5400, pickupLocation: "Training Ground", fee: 60.00, status: .completed)
    ]

    // Fetches lessons for the current instructor within a specific date range
    func fetchLessons(for instructorID: String, start: Date, end: Date) async throws -> [Lesson] {
        // --- Mock Data ---
        return publicMockLessons.filter { $0.startTime >= start && $0.startTime < end && $0.instructorID == "i_auth_id" }
    }

    // Creates a new lesson entry in Firestore
    func addLesson(newLesson: Lesson) async throws {
        try await Task.sleep(nanoseconds: 300_000_000)
        print("Lesson added successfully: \(newLesson.topic)")
        // Add to mock array for UI consistency
        publicMockLessons.append(newLesson)
    }
    
    // Updates the lesson status (e.g., completes a lesson)
    func updateLessonStatus(lessonID: String, status: LessonStatus) async throws {
        try await Task.sleep(nanoseconds: 200_000_000)
        if let index = publicMockLessons.firstIndex(where: { $0.id == lessonID }) {
            publicMockLessons[index].status = status
        }
        print("Lesson \(lessonID) updated to \(status.rawValue)")
    }
}
