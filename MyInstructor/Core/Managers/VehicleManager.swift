import Foundation
import FirebaseFirestore
import Combine

class VehicleManager: ObservableObject {
    private let db = Firestore.firestore()
    
    private var servicesCollection: CollectionReference {
        db.collection("vehicle_services")
    }
    
    private var vehiclesCollection: CollectionReference {
        db.collection("vehicles")
    }
    
    // MARK: - Vehicle CRUD
    
    func addVehicle(_ vehicle: Vehicle) async throws {
        try vehiclesCollection.addDocument(from: vehicle)
    }
    
    func updateVehicle(_ vehicle: Vehicle) async throws {
        guard let id = vehicle.id else { return }
        try vehiclesCollection.document(id).setData(from: vehicle)
    }
    
    func deleteVehicle(id: String) async throws {
        try await vehiclesCollection.document(id).delete()
    }
    
    func fetchVehicles(for instructorID: String) async throws -> [Vehicle] {
        let snapshot = try await vehiclesCollection
            .whereField("instructorID", isEqualTo: instructorID)
            .getDocuments()
        return snapshot.documents.compactMap { try? $0.data(as: Vehicle.self) }
    }
    
    // MARK: - Service Record CRUD
    
    func addServiceRecord(_ record: ServiceRecord) async throws {
        try servicesCollection.addDocument(from: record)
    }
    
    func updateServiceRecord(_ record: ServiceRecord) async throws {
        guard let id = record.id else { return }
        try servicesCollection.document(id).setData(from: record)
    }
    
    func deleteServiceRecord(id: String) async throws {
        try await servicesCollection.document(id).delete()
    }
    
    func fetchServiceRecords(for instructorID: String) async throws -> [ServiceRecord] {
        let snapshot = try await servicesCollection
            .whereField("instructorID", isEqualTo: instructorID)
            .order(by: "date", descending: true)
            .getDocuments()
        return snapshot.documents.compactMap { try? $0.data(as: ServiceRecord.self) }
    }
}
