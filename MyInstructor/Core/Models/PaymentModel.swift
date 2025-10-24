import Foundation
import FirebaseFirestore

// MARK: - Payment Model

struct Payment: Identifiable, Codable {
    @DocumentID var id: String?
    let studentID: String // The ID of the student who owes/paid
    var amount: Double
    var date: Date
    var isPaid: Bool // True if received, False if pending
}
