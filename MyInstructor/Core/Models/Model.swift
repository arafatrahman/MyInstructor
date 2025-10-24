import Foundation
import FirebaseFirestore // Need this for @DocumentID

// MARK: - Core User Models

enum UserRole: String, Codable, Hashable {
    case instructor = "instructor"
    case student = "student"
    case unselected = "unselected"
}

struct AppUser: Identifiable, Codable {
    @DocumentID var id: String? = nil
    let email: String
    var name: String?
    var role: UserRole
    var phone: String?
    var drivingSchool: String? // For instructor
    
    // Initializer for new Firebase Auth users
    init(id: String, email: String, name: String? = nil, role: UserRole = .unselected) {
        self.id = id
        self.email = email
        self.name = name
        self.role = role
    }
}

// Student model (Reused to represent both students and instructors in directory)
struct Student: Identifiable, Codable, Hashable { // <-- ADDED Hashable
    @DocumentID var id: String?
    let userID: String // The user's Firebase Auth ID
    var name: String
    var photoURL: String?
    var email: String
    var drivingSchool: String?
    
    // Calculated/Derived properties for dashboard/progress display
    var averageProgress: Double = 0.0 // 0.0 to 1.0
    var nextLessonTime: Date?
    var nextLessonTopic: String?
    
    // Since all properties are Hashable, default conformance is used.
    // If 'id' is nil, we rely on the object's identity for Hashable comparison.
    static func == (lhs: Student, rhs: Student) -> Bool {
        lhs.id == rhs.id
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

// MARK: - Lesson Models

struct Lesson: Identifiable, Codable {
    @DocumentID var id: String?
    let instructorID: String
    let studentID: String
    var topic: String
    var startTime: Date
    var duration: TimeInterval? // Stored duration in seconds
    var pickupLocation: String
    var fee: Double
    var notes: String?
    var status: LessonStatus = .scheduled
}

enum LessonStatus: String, Codable {
    case scheduled
    case completed
    case cancelled
}

extension TimeInterval {
    func formattedDuration() -> String {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.hour, .minute]
        formatter.unitsStyle = .abbreviated
        return formatter.string(from: self) ?? ""
    }
}
