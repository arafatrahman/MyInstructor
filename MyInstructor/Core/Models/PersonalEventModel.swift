// File: MyInstructor/Core/Models/PersonalEventModel.swift
import Foundation
import FirebaseFirestore

struct PersonalEvent: Identifiable, Codable {
    @DocumentID var id: String?
    let userID: String
    var title: String
    var date: Date
    var duration: TimeInterval // in seconds
    var notes: String?
    
    // Helper to get end time
    var endTime: Date {
        date.addingTimeInterval(duration)
    }
}
