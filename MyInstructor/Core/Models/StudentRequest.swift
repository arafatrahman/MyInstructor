// File: Core/Models/StudentRequest.swift
// --- UPDATED: Added .blocked status and blockedBy field ---

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
    
    // --- *** THIS IS THE NEW FIELD *** ---
    /// Tracks who initiated a block. Values: "student" or "instructor".
    var blockedBy: String?
}

enum RequestStatus: String, Codable {
    case pending
    case approved
    case denied
    case blocked // --- ADDED ---
}
