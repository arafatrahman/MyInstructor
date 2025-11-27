// File: MyInstructor/Core/Models/ExpenseModel.swift
import Foundation
import FirebaseFirestore

enum ExpenseCategory: String, Codable, CaseIterable, Identifiable {
    case fuel = "Fuel"
    case maintenance = "Maintenance"
    case insurance = "Insurance"
    case tax = "Tax"
    case marketing = "Marketing"
    case other = "Other"
    
    var id: String { self.rawValue }
}

struct Expense: Identifiable, Codable {
    @DocumentID var id: String?
    let instructorID: String
    var title: String
    var amount: Double
    var date: Date
    var category: ExpenseCategory
    var note: String?
}
