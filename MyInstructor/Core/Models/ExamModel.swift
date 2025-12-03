// File: arafatrahman/myinstructor/MyInstructor-main/MyInstructor/Core/Models/ExamModel.swift
// --- UPDATED: Added status, optional results for scheduling ---

import Foundation
import FirebaseFirestore

enum ExamStatus: String, Codable {
    case scheduled
    case completed
}

struct ExamResult: Identifiable, Codable {
    @DocumentID var id: String?
    let studentID: String
    var instructorID: String? // Optional: Links to instructor for their calendar
    
    var date: Date
    var testCenter: String
    var status: ExamStatus
    
    // Result Fields (Optional, only for completed exams)
    var isPass: Bool?
    var minorFaults: Int?
    var seriousFaults: Int?
    var notes: String?
    
    var summary: String {
        if status == .scheduled {
            return "Scheduled at \(testCenter)"
        } else {
            if isPass == true {
                return "Passed - \(minorFaults ?? 0) Minors"
            } else {
                return "Failed - \(seriousFaults ?? 0) Majors"
            }
        }
    }
}
