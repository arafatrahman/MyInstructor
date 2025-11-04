// File: Core/Models/StudentRequest.swift
// --- UPDATED: Added .blocked status ---

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
}

enum RequestStatus: String, Codable {
    case pending
    case approved
    case denied
    case blocked // --- ADDED ---
}
