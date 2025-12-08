// File: arafatrahman/myinstructor/MyInstructor-main/MyInstructor/Core/Models/StudentRequest.swift
// --- UPDATED: Added 'completed' status ---

import Foundation
import FirebaseFirestore

struct StudentRequest: Identifiable, Codable {
    @DocumentID var id: String?
    let studentID: String
    let studentName: String
    let studentPhotoURL: String?
    let instructorID: String
    var status: RequestStatus
    let timestamp: Date
    
    /// Tracks who initiated a block. Values: "student" or "instructor".
    var blockedBy: String?
}

enum RequestStatus: String, Codable {
    case pending
    case approved
    case denied
    case blocked
    case completed // --- ADDED ---
}
