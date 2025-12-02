// File: arafatrahman/myinstructor/MyInstructor-main/MyInstructor/Core/Models/Model.swift
// --- UPDATED: Added 'title' field to PracticeSession ---

import Foundation
import FirebaseFirestore
import CoreLocation

// MARK: - Core User Models
enum UserRole: String, Codable, Hashable {
    case instructor = "instructor", student = "student", unselected = "unselected"
}

struct EducationEntry: Identifiable, Codable, Hashable {
    var id = UUID()
    var title: String, subtitle: String, years: String
}

struct AppUser: Identifiable, Codable {
    @DocumentID var id: String? = nil
    let email: String
    var name: String?
    var role: UserRole
    var phone: String?
    var drivingSchool: String?
    var photoURL: String?
    var address: String?
    var hourlyRate: Double?
    var aboutMe: String?
    var education: [EducationEntry]?
    var expertise: [String]?
    var studentIDs: [String]?
    var instructorIDs: [String]?

    init(id: String, email: String, name: String? = nil, role: UserRole = .unselected) {
        self.id = id; self.email = email; self.name = name; self.role = role
    }
}

// Student model
struct Student: Identifiable, Codable, Hashable {
    @DocumentID var id: String?
    let userID: String
    var name: String
    var photoURL: String?
    var email: String
    var drivingSchool: String?
    var phone: String?
    var address: String?
    var distance: Double?
    var coordinate: CLLocationCoordinate2D?
    var isOffline: Bool = false
    var averageProgress: Double = 0.0
    var nextLessonTime: Date?
    var nextLessonTopic: String?
    
    enum CodingKeys: String, CodingKey {
        case id, userID, name, photoURL, email, drivingSchool, phone, address, averageProgress, nextLessonTime, nextLessonTopic, isOffline
    }
    static func == (lhs: Student, rhs: Student) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}

// MARK: - Note Models
struct StudentNote: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    let content: String
    let timestamp: Date
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.content = try container.decode(String.self, forKey: .content)
        self.timestamp = try container.decode(Date.self, forKey: .timestamp)
        self.id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
    }
    
    init(id: UUID = UUID(), content: String, timestamp: Date) {
        self.id = id
        self.content = content
        self.timestamp = timestamp
    }
    
    enum CodingKeys: String, CodingKey {
        case id, content, timestamp
    }
}

struct StudentRecord: Identifiable, Codable {
    @DocumentID var id: String?
    var progress: Double?
    var notes: [StudentNote]?
}

// MARK: - Lesson Models
struct Lesson: Identifiable, Codable {
    @DocumentID var id: String?
    let instructorID: String
    let studentID: String
    var topic: String
    var startTime: Date
    var duration: TimeInterval?
    var pickupLocation: String
    var fee: Double
    var notes: String?
    var status: LessonStatus = .scheduled
}

enum LessonStatus: String, Codable {
    case scheduled, completed, cancelled
}

extension TimeInterval {
    func formattedDuration() -> String {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.hour, .minute]
        formatter.unitsStyle = .abbreviated
        return formatter.string(from: self) ?? ""
    }
}

// MARK: - Offline Student Model
struct OfflineStudent: Identifiable, Codable, Hashable {
    @DocumentID var id: String?
    let instructorID: String
    var name: String
    var phone: String?
    var email: String?
    var address: String?
    @ServerTimestamp var timestamp: Date? = Date()
    var progress: Double? = 0.0
    var notes: [StudentNote]? = []
}

// MARK: - Notification Model
struct AppNotification: Identifiable, Codable {
    @DocumentID var id: String?
    let recipientID: String
    let title: String
    let message: String
    let type: String
    let timestamp: Date
    var isRead: Bool
}

// MARK: - Practice Session Model (Student Log)
struct PracticeSession: Identifiable, Codable {
    @DocumentID var id: String?
    let studentID: String
    var date: Date
    var duration: TimeInterval // in seconds
    var practiceType: String // "Private Practice", "Official Lesson", etc.
    var topic: String?
    
    // --- NEW: Separate title field for notes ---
    var title: String?
    var notes: String?
    
    // Helper to convert to hours for display
    var durationHours: Double {
        return duration / 3600.0
    }
}
