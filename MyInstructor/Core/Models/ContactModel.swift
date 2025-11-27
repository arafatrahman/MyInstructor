// File: arafatrahman/myinstructor/MyInstructor-main/MyInstructor/Core/Models/ContactModel.swift
import Foundation
import FirebaseFirestore

struct CustomContact: Identifiable, Codable, Hashable {
    @DocumentID var id: String?
    let instructorID: String
    var name: String
    var phone: String
    var email: String?
    var note: String?
}
