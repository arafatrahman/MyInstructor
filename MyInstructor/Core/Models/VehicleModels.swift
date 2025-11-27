import Foundation
import FirebaseFirestore

struct Vehicle: Identifiable, Codable, Hashable {
    @DocumentID var id: String?
    let instructorID: String
    var make: String
    var model: String
    var year: String
    var licensePlate: String
    var nickname: String?
    var photoURLs: [String]? // --- ADDED: Store photo URLs
    
    var displayName: String {
        if let nick = nickname, !nick.isEmpty { return nick }
        return "\(make) \(model) (\(licensePlate))"
    }
}

struct ServiceRecord: Identifiable, Codable {
    @DocumentID var id: String?
    let instructorID: String
    var vehicleID: String?
    var date: Date
    var mileage: Int
    var serviceType: String
    var garageName: String
    var cost: Double
    var notes: String?
    var nextServiceDate: Date?
}
