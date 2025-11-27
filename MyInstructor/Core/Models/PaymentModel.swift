// File: arafatrahman/myinstructor/MyInstructor-main/MyInstructor/Core/Models/PaymentModel.swift
import Foundation
import FirebaseFirestore

// MARK: - Payment Model

enum PaymentMethod: String, Codable, CaseIterable, Identifiable {
    case cash = "Cash"
    case card = "Card"
    case bankTransfer = "Bank Transfer"
    
    var id: String { self.rawValue }
}

struct Payment: Identifiable, Codable {
    @DocumentID var id: String?
    let instructorID: String // The ID of the instructor (user)
    let studentID: String // The ID of the student who owes/paid
    var amount: Double
    var date: Date
    var isPaid: Bool // True if received, False if pending
    var paymentMethod: PaymentMethod? // Optional: Cash, Card, Bank Transfer
}
