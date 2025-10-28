import Foundation
import FirebaseFirestore
import Combine

class PaymentManager: ObservableObject {
    private let db = Firestore.firestore()
    private var paymentsCollection: CollectionReference {
        db.collection("payments")
    }
    
    // Note: The 'publicMockPayments' array has been removed.

    func recordPayment(newPayment: Payment) async throws {
        try paymentsCollection.addDocument(from: newPayment)
        print("Payment recorded successfully: \(newPayment.amount)")
    }
    
    func updatePaymentStatus(paymentID: String, isPaid: Bool) async throws {
        try await paymentsCollection.document(paymentID).updateData(["isPaid": isPaid])
        print("Payment \(paymentID) status updated to \(isPaid)")
    }
    
    func fetchInstructorPayments(for instructorID: String) async throws -> [Payment] {
        // This query is difficult as the 'Payment' model only has 'studentID'.
        // A real schema might require payments to also store 'instructorID',
        // or we'd have to fetch all students for an instructor, then
        // fetch all payments for *each* of those students.
        
        // For this exercise, I will assume payments *should* have an 'instructorID'.
        // Since the model doesn't, this query will return payments for a *student*.
        // This highlights a schema issue.
        
        // TODO: Adjust data model. Assuming 'studentID' is what we
        // meant to query by (e.g., a student checking their own payments).
        // If it's an instructor, the 'payments' collection needs 'instructorID'.
        
        // Returning empty as the query is ambiguous based on the model.
        
        // --- IF MODEL WAS CORRECT (Payment has instructorID): ---
        // let snapshot = try await paymentsCollection
        //     .whereField("instructorID", isEqualTo: instructorID)
        //     .order(by: "date", descending: true)
        //     .getDocuments()
        //
        // let payments = snapshot.documents.compactMap { try? $0.data(as: Payment.self) }
        // return payments
        
        print("fetchInstructorPayments needs a schema update (Payment model requires instructorID)")
        return []
    }
}
