// File: arafatrahman/myinstructor/MyInstructor-main/MyInstructor/Core/Models/Model.swift

import Foundation
import FirebaseFirestore // Need this for @DocumentID
import CoreLocation // <-- ADDED

// MARK: - Core User Models

enum UserRole: String, Codable, Hashable {
    case instructor = "instructor"
    case student = "student"
    case unselected = "unselected"
}

// --- THIS IS THE MODIFIED STRUCT ---
struct EducationEntry: Identifiable, Codable, Hashable {
    var id = UUID()
    var title: String    // Replaces 'school'
    var subtitle: String // Replaces 'degree'
    var years: String
}
// ------------------------------------

struct AppUser: Identifiable, Codable {
    @DocumentID var id: String? = nil
    let email: String
    var name: String?
    var role: UserRole
    var phone: String?
    var drivingSchool: String? // For instructor
    
    // --- ADDED/MODIFIED FIELDS ---
    var photoURL: String?
    var address: String?
    var hourlyRate: Double? // For instructor
    
    // --- THESE ARE THE NEW FIELDS ---
    var aboutMe: String?
    var education: [EducationEntry]? // Uses new struct
    var expertise: [String]? // For instructor
    // --------------------------------
    
    // --- *** ADD THESE NEW RELATIONSHIP FIELDS *** ---
    // For Instructors: An array of their approved student User IDs
    var studentIDs: [String]?
    // For Students: An array of their approved instructor User IDs
    var instructorIDs: [String]?
    // ---------------------------------------------

    // Initializer for new Firebase Auth users
    init(id: String, email: String, name: String? = nil, role: UserRole = .unselected) {
        self.id = id
        self.email = email
        self.name = name
        self.role = role
    }
}

// Student model (Reused to represent both students and instructors in directory)
struct Student: Identifiable, Codable, Hashable {
    @DocumentID var id: String?
    let userID: String // The user's Firebase Auth ID
    var name: String
    var photoURL: String?
    var email: String
    var drivingSchool: String?
    
    // --- *** ADDED/MODIFIED FIELDS FOR SEARCH & SORTING *** ---
    var phone: String?
    var address: String?
    var distance: Double? // Used for sorting by proximity, in meters
    var coordinate: CLLocationCoordinate2D? // <-- ADDED FOR MAP PINS
    // --- *** END OF ADDED/MODIFIED FIELDS *** ---
    
    // Calculated/Derived properties for dashboard/progress display
    var averageProgress: Double = 0.0 // 0.0 to 1.0
    var nextLessonTime: Date?
    var nextLessonTopic: String?
    
    // --- CODABLE CONFORMANCE (To exclude view-only properties) ---
    enum CodingKeys: String, CodingKey {
        case id, userID, name, photoURL, email, drivingSchool, phone, address
        case averageProgress, nextLessonTime, nextLessonTopic
        // `distance` and `coordinate` are omitted, so they won'Do not be encoded/decoded
    }
    
    static func == (lhs: Student, rhs: Student) -> Bool {
        lhs.id == rhs.id
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id) // Hashing on `id` is sufficient
    }
}

// MARK: - Lesson Models
// ... (rest of file is unchanged)
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
