import Foundation
import Combine
/*
 DataService acts as the common interface for fetching and providing data. 
 For this phase, it provides sophisticated mock data.
 */
class DataService: ObservableObject {
    
    // Mock data storage for quick lookups
    private var mockStudents: [Student] = []
    private var mockLessons: [Lesson] = []

    init() {
        // Initialize mock data on startup
        setupMockData()
    }
    
    private func setupMockData() {
        // Mock Students
        mockStudents = [
            Student(
                id: "student_abc",
                userID: "abc_123",
                name: "Emma Watson",
                email: "emma@example.com",
                averageProgress: 0.85,
                nextLessonTime: Calendar.current.date(byAdding: .hour, value: 2, to: Date()),
                nextLessonTopic: "Emergency Stops"
            ),
            Student(
                id: "student_xyz",
                userID: "xyz_456",
                name: "Alex Johnson",
                email: "alex@example.com",
                averageProgress: 0.65,
                nextLessonTime: Calendar.current.date(byAdding: .day, value: 3, to: Date())!.addingTimeInterval(3600*14),
                nextLessonTopic: "Roundabouts"
            ),
            Student(
                id: "student_def",
                userID: "def_789",
                name: "Chloe Davis",
                email: "chloe@example.com",
                averageProgress: 0.40,
                nextLessonTime: nil
            )
        ]
        
        // Mock Lessons (must reference mock student IDs)
        mockLessons = [
            Lesson(instructorID: "i_auth_id", studentID: "student_abc", topic: "Manoeuvres: Parking", startTime: Date().addingTimeInterval(3600*2), pickupLocation: "10 Downing St", fee: 45.00),
            Lesson(instructorID: "i_auth_id", studentID: "student_xyz", topic: "Junctions", startTime: Date().addingTimeInterval(-3600*12), duration: 3600, pickupLocation: "High Street", fee: 40.00, status: .completed),
            Lesson(instructorID: "i_auth_id", studentID: "student_def", topic: "Basic Controls", startTime: Date().addingTimeInterval(-3600*48), duration: 5400, pickupLocation: "Training Ground", fee: 60.00, status: .completed)
        ]
    }
    
    // MARK: - Dashboard Data Fetching
    
    func fetchInstructorDashboardData(for instructorID: String) async throws -> (nextLesson: Lesson?, earnings: Double, avgProgress: Double) {
        try await Task.sleep(nanoseconds: 500_000_000)
        
        let nextLesson = mockLessons.filter { $0.instructorID == instructorID && $0.status == .scheduled }.sorted { $0.startTime < $1.startTime }.first
        
        let weeklyEarnings = 350.00 // Mock value
        let averageStudentProgress = mockStudents.reduce(0) { $0 + $1.averageProgress } / Double(mockStudents.count)
        
        return (nextLesson, weeklyEarnings, averageStudentProgress)
    }

    func fetchStudentDashboardData(for studentID: String) async throws -> (upcomingLesson: Lesson?, progress: Double, latestFeedback: String, paymentDue: Bool) {
        try await Task.sleep(nanoseconds: 500_000_000)
        
        let upcomingLesson = mockLessons.filter { $0.studentID == studentID && $0.status == .scheduled }.sorted { $0.startTime < $1.startTime }.first
        let student = mockStudents.first { $0.id == studentID }
        
        let progressValue = student?.averageProgress ?? 0.0
        let feedback = "Great control on the clutch. Focus on signaling earlier at complex junctions."
        let paymentStatus = true
        
        return (upcomingLesson, progressValue, feedback, paymentStatus)
    }
    
    // MARK: - User Management Fetching
    
    func fetchStudents(for instructorID: String) async throws -> [Student] {
        try await Task.sleep(nanoseconds: 500_000_000)
        return mockStudents
    }
    
    func getStudentName(for studentID: String) -> String {
        return mockStudents.first { $0.id == studentID }?.name ?? "Unknown Student"
    }
}
