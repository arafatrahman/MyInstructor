// File: arafatrahman/myinstructor/MyInstructor-main/MyInstructor/Core/Models/PaymentModel.swift
// --- UPDATED: Added 'hours' field ---

import Foundation
import FirebaseFirestore

enum PaymentMethod: String, Codable, CaseIterable, Identifiable {
    case cash = "Cash"
    case card = "Card"
    case bankTransfer = "Bank Transfer"
    
    var id: String { self.rawValue }
}

struct Payment: Identifiable, Codable {
    @DocumentID var id: String?
    let instructorID: String // Can be empty string "" if not linked to a specific instructor
    let studentID: String
    var amount: Double
    var date: Date
    var isPaid: Bool
    var paymentMethod: PaymentMethod?
    var note: String?
    var hours: Double? // <--- NEW: Optional hours field
}
