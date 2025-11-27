// File: arafatrahman/myinstructor/MyInstructor-main/MyInstructor/Core/Managers/PaymentManager.swift
import Foundation
import FirebaseFirestore
import Combine

class PaymentManager: ObservableObject {
    private let db = Firestore.firestore()
    private var paymentsCollection: CollectionReference {
        db.collection("payments")
    }
    
    // Create
    func recordPayment(newPayment: Payment) async throws {
        try paymentsCollection.addDocument(from: newPayment)
        print("Payment recorded successfully: \(newPayment.amount)")
    }
    
    // Update Status Only (Quick Action)
    func updatePaymentStatus(paymentID: String, isPaid: Bool) async throws {
        try await paymentsCollection.document(paymentID).updateData(["isPaid": isPaid])
        print("Payment \(paymentID) status updated to \(isPaid)")
    }
    
    // Update Full Payment (Edit)
    func updatePayment(_ payment: Payment) async throws {
        guard let paymentID = payment.id else { return }
        try paymentsCollection.document(paymentID).setData(from: payment)
        print("Payment \(paymentID) updated successfully")
    }
    
    // Delete
    func deletePayment(paymentID: String) async throws {
        try await paymentsCollection.document(paymentID).delete()
        print("Payment \(paymentID) deleted successfully")
    }
    
    // Fetch
    func fetchInstructorPayments(for instructorID: String) async throws -> [Payment] {
        let snapshot = try await paymentsCollection
            .whereField("instructorID", isEqualTo: instructorID)
            .order(by: "date", descending: true)
            .getDocuments()
        
        let payments = snapshot.documents.compactMap { try? $0.data(as: Payment.self) }
        return payments
    }
}
