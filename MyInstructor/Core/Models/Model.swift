// File: arafatrahman/myinstructor/MyInstructor-main/MyInstructor/Core/Models/Model.swift
// --- UPDATED: Added 'isOffline' property to Student struct ---

import Foundation
import FirebaseFirestore
import CoreLocation

// MARK: - Core User Models

enum UserRole: String, Codable, Hashable {
    case instructor = "instructor"
    case student = "student"
    case unselected = "unselected"
}

struct EducationEntry: Identifiable, Codable, Hashable {
    var id = UUID()
    var title: String
    var subtitle: String
    var years: String
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
        self.id = id
        self.email = email
        self.name = name
        self.role = role
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
    
    // --- *** ADDED: Flag to distinguish offline students *** ---
    var isOffline: Bool = false
    // --- *** ---
    
    var averageProgress: Double = 0.0
    var nextLessonTime: Date?
    var nextLessonTopic: String?
    
    enum CodingKeys: String, CodingKey {
        case id, userID, name, photoURL, email, drivingSchool, phone, address
        case averageProgress, nextLessonTime, nextLessonTopic
        case isOffline // Added to coding keys
    }
    
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
    var duration: TimeInterval?
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

// MARK: - Offline Student Model
struct OfflineStudent: Identifiable, Codable, Hashable {
    @DocumentID var id: String?
    let instructorID: String
    var name: String
    var phone: String?
    var email: String?
    var address: String?
    @ServerTimestamp var timestamp: Date? = Date()
}
