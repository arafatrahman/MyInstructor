import Foundation
import FirebaseFirestore
import Combine // Added Combine for ObservableObject

class PaymentManager: ObservableObject {
    private let db = Firestore.firestore()
    private let paymentsCollection = "payments"
    
    // MADE PUBLIC to allow views like StudentProfileView to access mock data for filtering.
    public var publicMockPayments: [Payment] = [
        Payment(id: "pay1", studentID: "student_abc", amount: 45.0, date: Date().addingTimeInterval(-86400*2), isPaid: false),
        Payment(id: "pay2", studentID: "student_xyz", amount: 40.0, date: Date().addingTimeInterval(-86400*5), isPaid: true),
        Payment(id: "pay3", studentID: "student_abc", amount: 45.0, date: Date().addingTimeInterval(-86400*10), isPaid: true),
        Payment(id: "pay4", studentID: "student_def", amount: 90.0, date: Date().addingTimeInterval(-86400*15), isPaid: false),
    ]

    func recordPayment(newPayment: Payment) async throws {
        // In a real app: try db.collection(paymentsCollection).addDocument(from: newPayment)
        try await Task.sleep(nanoseconds: 300_000_000)
        print("Payment recorded successfully: \(newPayment.amount)")
        
        // Update the mock data source
        publicMockPayments.append(newPayment)
    }
    
    func updatePaymentStatus(paymentID: String, isPaid: Bool) async throws {
        // In a real app: try await db.collection(paymentsCollection).document(paymentID).updateData(["isPaid": isPaid])
        try await Task.sleep(nanoseconds: 200_000_000)
        if let index = publicMockPayments.firstIndex(where: { $0.id == paymentID }) {
            publicMockPayments[index].isPaid = isPaid
        }
        print("Payment \(paymentID) status updated to \(isPaid)")
    }
    
    func fetchInstructorPayments(for instructorID: String) async throws -> [Payment] {
        try await Task.sleep(nanoseconds: 500_000_000)
        // Returns all mock payments for the demo
        return publicMockPayments
    }
}
