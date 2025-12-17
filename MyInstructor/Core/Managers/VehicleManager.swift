// File: arafatrahman/myinstructor/MyInstructor-main/MyInstructor/Core/Managers/VehicleManager.swift
// --- UPDATED: Added Mileage Log CRUD ---

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
    
    // --- NEW COLLECTION ---
    private var mileageCollection: CollectionReference {
        db.collection("mileage_logs")
    }
    
    // MARK: - Vehicle CRUD
    
    func addVehicle(_ vehicle: Vehicle) async throws {
        // When adding, id is usually nil, but we enforce it just in case
        var vehicleToSave = vehicle
        vehicleToSave.id = nil
        try vehiclesCollection.addDocument(from: vehicleToSave)
    }
    
    func updateVehicle(_ vehicle: Vehicle) async throws {
        guard let id = vehicle.id else { return }
        
        // Create a copy and set id to nil to avoid [I-FST000002] warning
        var vehicleToSave = vehicle
        vehicleToSave.id = nil
        
        try vehiclesCollection.document(id).setData(from: vehicleToSave)
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
        var recordToSave = record
        recordToSave.id = nil
        try servicesCollection.addDocument(from: recordToSave)
    }
    
    func updateServiceRecord(_ record: ServiceRecord) async throws {
        guard let id = record.id else { return }
        
        // Create a copy and set id to nil to avoid [I-FST000002] warning
        var recordToSave = record
        recordToSave.id = nil
        
        try servicesCollection.document(id).setData(from: recordToSave)
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
    
    // MARK: - Mileage Log CRUD (NEW)
    
    func addMileageLog(_ log: MileageLog) async throws {
        var logToSave = log
        logToSave.id = nil
        try mileageCollection.addDocument(from: logToSave)
    }
    
    func deleteMileageLog(id: String) async throws {
        try await mileageCollection.document(id).delete()
    }
    
    func fetchMileageLogs(for instructorID: String) async throws -> [MileageLog] {
        let snapshot = try await mileageCollection
            .whereField("instructorID", isEqualTo: instructorID)
            .order(by: "date", descending: true)
            .getDocuments()
        return snapshot.documents.compactMap { try? $0.data(as: MileageLog.self) }
    }
}
