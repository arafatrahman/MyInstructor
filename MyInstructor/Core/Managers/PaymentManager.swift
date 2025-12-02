// File: arafatrahman/myinstructor/MyInstructor-main/MyInstructor/Core/Managers/PaymentManager.swift

import Foundation
import FirebaseFirestore
import Combine

class PaymentManager: ObservableObject {
    private let db = Firestore.firestore()
    private var paymentsCollection: CollectionReference {
        db.collection("payments")
    }
    
    // MARK: - Create
    func recordPayment(newPayment: Payment) async throws {
        try paymentsCollection.addDocument(from: newPayment)
    }
    
    // MARK: - Update
    /// Updates the full payment details (amount, date, method, notes, etc.)
    func updatePayment(_ payment: Payment) async throws {
        guard let paymentID = payment.id else { return }
        try paymentsCollection.document(paymentID).setData(from: payment)
    }
    
    /// Updates only the "isPaid" status (useful for quick toggles)
    func updatePaymentStatus(paymentID: String, isPaid: Bool) async throws {
        try await paymentsCollection.document(paymentID).updateData(["isPaid": isPaid])
    }
    
    // MARK: - Delete
    func deletePayment(paymentID: String) async throws {
        try await paymentsCollection.document(paymentID).delete()
    }
    
    // MARK: - Fetching
    
    /// Fetches all payments associated with a specific INSTRUCTOR
    func fetchInstructorPayments(for instructorID: String) async throws -> [Payment] {
        let snapshot = try await paymentsCollection
            .whereField("instructorID", isEqualTo: instructorID)
            .order(by: "date", descending: true)
            .getDocuments()
        
        return snapshot.documents.compactMap { try? $0.data(as: Payment.self) }
    }
    
    /// Fetches all payments associated with a specific STUDENT
    func fetchStudentPayments(for studentID: String) async throws -> [Payment] {
        let snapshot = try await paymentsCollection
            .whereField("studentID", isEqualTo: studentID)
            .order(by: "date", descending: true)
            .getDocuments()
        
        return snapshot.documents.compactMap { try? $0.data(as: Payment.self) }
    }
}
