// File: arafatrahman/myinstructor/MyInstructor-main/MyInstructor/Core/Managers/BackupManager.swift
// --- FULLY UPDATED: Includes MileageLog and VaultDocument support ---

import Foundation
import FirebaseFirestore

// MARK: - Backup DTOs (Plain Codable Structs)

struct BackupData: Codable {
    let version: String
    let timestamp: Date
    let userProfile: BackupUser?
    let lessons: [BackupLesson]
    let expenses: [BackupExpense]
    let vehicles: [BackupVehicle]
    let serviceRecords: [BackupServiceRecord]
    let payments: [BackupPayment]
    let offlineStudents: [BackupOfflineStudent]
    // --- NEW FIELDS ---
    let mileageLogs: [BackupMileageLog]
    let vaultDocuments: [BackupVaultDocument]
}

struct BackupUser: Codable {
    let id: String?
    let email: String
    let name: String?
    let role: UserRole
    let phone: String?
    let drivingSchool: String?
    let photoURL: String?
    let address: String?
    let hourlyRate: Double?
    let aboutMe: String?
    let education: [EducationEntry]?
    let expertise: [String]?
    let studentIDs: [String]?
    let instructorIDs: [String]?
    let following: [String]?
    let followers: [String]?
    let blockedUsers: [String]?
    let isPrivate: Bool?
    let hideFollowers: Bool?
    let hideEmail: Bool?
    
    init(from user: AppUser) {
        self.id = user.id
        self.email = user.email
        self.name = user.name
        self.role = user.role
        self.phone = user.phone
        self.drivingSchool = user.drivingSchool
        self.photoURL = user.photoURL
        self.address = user.address
        self.hourlyRate = user.hourlyRate
        self.aboutMe = user.aboutMe
        self.education = user.education
        self.expertise = user.expertise
        self.studentIDs = user.studentIDs
        self.instructorIDs = user.instructorIDs
        self.following = user.following
        self.followers = user.followers
        self.blockedUsers = user.blockedUsers
        self.isPrivate = user.isPrivate
        self.hideFollowers = user.hideFollowers
        self.hideEmail = user.hideEmail
    }
}

struct BackupLesson: Codable {
    let id: String?
    let instructorID: String
    let studentID: String
    let topic: String
    let startTime: Date
    let duration: TimeInterval?
    let pickupLocation: String
    let fee: Double
    let notes: String?
    let status: LessonStatus
    let isLocationActive: Bool?
    
    init(from lesson: Lesson) {
        self.id = lesson.id
        self.instructorID = lesson.instructorID
        self.studentID = lesson.studentID
        self.topic = lesson.topic
        self.startTime = lesson.startTime
        self.duration = lesson.duration
        self.pickupLocation = lesson.pickupLocation
        self.fee = lesson.fee
        self.notes = lesson.notes
        self.status = lesson.status
        self.isLocationActive = lesson.isLocationActive
    }
}

struct BackupExpense: Codable {
    let id: String?
    let instructorID: String
    let title: String
    let amount: Double
    let date: Date
    let category: ExpenseCategory
    let note: String?
    
    init(from expense: Expense) {
        self.id = expense.id
        self.instructorID = expense.instructorID
        self.title = expense.title
        self.amount = expense.amount
        self.date = expense.date
        self.category = expense.category
        self.note = expense.note
    }
}

struct BackupVehicle: Codable {
    let id: String?
    let instructorID: String
    let make: String
    let model: String
    let year: String
    let licensePlate: String
    let nickname: String?
    let photoURLs: [String]?
    let insuranceExpiry: Date?
    let motExpiry: Date?
    
    init(from vehicle: Vehicle) {
        self.id = vehicle.id
        self.instructorID = vehicle.instructorID
        self.make = vehicle.make
        self.model = vehicle.model
        self.year = vehicle.year
        self.licensePlate = vehicle.licensePlate
        self.nickname = vehicle.nickname
        self.photoURLs = vehicle.photoURLs
        self.insuranceExpiry = vehicle.insuranceExpiry
        self.motExpiry = vehicle.motExpiry
    }
}

struct BackupServiceRecord: Codable {
    let id: String?
    let instructorID: String
    let vehicleID: String?
    let date: Date
    let mileage: Int
    let serviceType: String
    let garageName: String
    let cost: Double
    let notes: String?
    let nextServiceDate: Date?
    
    init(from record: ServiceRecord) {
        self.id = record.id
        self.instructorID = record.instructorID
        self.vehicleID = record.vehicleID
        self.date = record.date
        self.mileage = record.mileage
        self.serviceType = record.serviceType
        self.garageName = record.garageName
        self.cost = record.cost
        self.notes = record.notes
        self.nextServiceDate = record.nextServiceDate
    }
}

struct BackupPayment: Codable {
    let id: String?
    let instructorID: String
    let studentID: String
    let amount: Double
    let date: Date
    let isPaid: Bool
    let paymentMethod: PaymentMethod?
    let note: String?
    let hours: Double?
    
    init(from payment: Payment) {
        self.id = payment.id
        self.instructorID = payment.instructorID
        self.studentID = payment.studentID
        self.amount = payment.amount
        self.date = payment.date
        self.isPaid = payment.isPaid
        self.paymentMethod = payment.paymentMethod
        self.note = payment.note
        self.hours = payment.hours
    }
}

struct BackupOfflineStudent: Codable {
    let id: String?
    let instructorID: String
    let name: String
    let phone: String?
    let email: String?
    let address: String?
    let timestamp: Date?
    let progress: Double?
    let notes: [StudentNote]?
    
    init(from student: OfflineStudent) {
        self.id = student.id
        self.instructorID = student.instructorID
        self.name = student.name
        self.phone = student.phone
        self.email = student.email
        self.address = student.address
        self.timestamp = student.timestamp
        self.progress = student.progress
        self.notes = student.notes
    }
}

struct BackupMileageLog: Codable {
    let id: String?
    let instructorID: String
    let vehicleID: String
    let date: Date
    let startReading: Int
    let endReading: Int
    let purpose: String
    let notes: String?
    
    init(from log: MileageLog) {
        self.id = log.id
        self.instructorID = log.instructorID
        self.vehicleID = log.vehicleID
        self.date = log.date
        self.startReading = log.startReading
        self.endReading = log.endReading
        self.purpose = log.purpose
        self.notes = log.notes
    }
}

struct BackupVaultDocument: Codable {
    let id: String?
    let userID: String
    let title: String
    let date: Date
    let url: String
    let notes: String?
    let fileType: String
    let isEncrypted: Bool
    
    init(from doc: VaultDocument) {
        self.id = doc.id
        self.userID = doc.userID
        self.title = doc.title
        self.date = doc.date
        self.url = doc.url
        self.notes = doc.notes
        self.fileType = doc.fileType
        self.isEncrypted = doc.isEncrypted
    }
}

// MARK: - Manager Class

class BackupManager {
    static let shared = BackupManager()
    
    private let db = Firestore.firestore()
    
    private init() {}
    
    // MARK: - Export
    func createBackupData(for userID: String) async throws -> Data {
        // 1. Fetch User Profile
        let userDoc = try await db.collection("users").document(userID).getDocument()
        let userProfile = try? userDoc.data(as: AppUser.self)
        let backupProfile = userProfile.map { BackupUser(from: $0) }
        
        // 2. Fetch Lessons
        let lessonsSnapshot = try await db.collection("lessons").whereField("instructorID", isEqualTo: userID).getDocuments()
        let lessons = lessonsSnapshot.documents.compactMap { try? $0.data(as: Lesson.self) }.map { BackupLesson(from: $0) }
        
        // 3. Fetch Expenses
        let expensesSnapshot = try await db.collection("expenses").whereField("instructorID", isEqualTo: userID).getDocuments()
        let expenses = expensesSnapshot.documents.compactMap { try? $0.data(as: Expense.self) }.map { BackupExpense(from: $0) }
        
        // 4. Fetch Vehicles
        let vehiclesSnapshot = try await db.collection("vehicles").whereField("instructorID", isEqualTo: userID).getDocuments()
        let vehicles = vehiclesSnapshot.documents.compactMap { try? $0.data(as: Vehicle.self) }.map { BackupVehicle(from: $0) }
        
        // 5. Fetch Service Records
        let servicesSnapshot = try await db.collection("vehicle_services").whereField("instructorID", isEqualTo: userID).getDocuments()
        let serviceRecords = servicesSnapshot.documents.compactMap { try? $0.data(as: ServiceRecord.self) }.map { BackupServiceRecord(from: $0) }
        
        // 6. Fetch Payments
        let paymentsSnapshot = try await db.collection("payments").whereField("instructorID", isEqualTo: userID).getDocuments()
        let payments = paymentsSnapshot.documents.compactMap { try? $0.data(as: Payment.self) }.map { BackupPayment(from: $0) }
        
        // 7. Fetch Offline Students
        let offlineSnapshot = try await db.collection("offline_students").whereField("instructorID", isEqualTo: userID).getDocuments()
        let offlineStudents = offlineSnapshot.documents.compactMap { try? $0.data(as: OfflineStudent.self) }.map { BackupOfflineStudent(from: $0) }
        
        // 8. Fetch Mileage Logs
        let mileageSnapshot = try await db.collection("mileage_logs").whereField("instructorID", isEqualTo: userID).getDocuments()
        let mileageLogs = mileageSnapshot.documents.compactMap { try? $0.data(as: MileageLog.self) }.map { BackupMileageLog(from: $0) }
        
        // 9. Fetch Vault Documents
        let vaultSnapshot = try await db.collection("vault_documents").whereField("userID", isEqualTo: userID).getDocuments()
        let vaultDocuments = vaultSnapshot.documents.compactMap { try? $0.data(as: VaultDocument.self) }.map { BackupVaultDocument(from: $0) }
        
        // Bundle
        let backup = BackupData(
            version: "1.1",
            timestamp: Date(),
            userProfile: backupProfile,
            lessons: lessons,
            expenses: expenses,
            vehicles: vehicles,
            serviceRecords: serviceRecords,
            payments: payments,
            offlineStudents: offlineStudents,
            mileageLogs: mileageLogs,
            vaultDocuments: vaultDocuments
        )
        
        // Encode
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        encoder.dateEncodingStrategy = .iso8601
        return try encoder.encode(backup)
    }
    
    // MARK: - Import
    func restoreBackup(from url: URL, for userID: String) async throws {
        // 1. Decode
        let data = try Data(contentsOf: url)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let backup = try decoder.decode(BackupData.self, from: data)
        
        // 2. Restore logic (Save directly as DTOs, Firestore allows Encodable)
        
        // Lessons
        for item in backup.lessons {
            if item.instructorID == userID {
                try saveData(item, collection: "lessons", id: item.id)
            }
        }
        
        // Expenses
        for item in backup.expenses {
            if item.instructorID == userID {
                try saveData(item, collection: "expenses", id: item.id)
            }
        }
        
        // Vehicles
        for item in backup.vehicles {
            if item.instructorID == userID {
                try saveData(item, collection: "vehicles", id: item.id)
            }
        }
        
        // Service Records
        for item in backup.serviceRecords {
            if item.instructorID == userID {
                try saveData(item, collection: "vehicle_services", id: item.id)
            }
        }
        
        // Payments
        for item in backup.payments {
            if item.instructorID == userID {
                try saveData(item, collection: "payments", id: item.id)
            }
        }
        
        // Offline Students
        for item in backup.offlineStudents {
            if item.instructorID == userID {
                try saveData(item, collection: "offline_students", id: item.id)
            }
        }
        
        // Mileage Logs
        for item in backup.mileageLogs {
            if item.instructorID == userID {
                try saveData(item, collection: "mileage_logs", id: item.id)
            }
        }
        
        // Vault Documents
        for item in backup.vaultDocuments {
            if item.userID == userID {
                try saveData(item, collection: "vault_documents", id: item.id)
            }
        }
        
        print("Restore completed successfully.")
    }
    
    // Helper to save generic Encodable
    private func saveData<T: Encodable>(_ data: T, collection: String, id: String?) throws {
        if let id = id {
            try db.collection(collection).document(id).setData(from: data, merge: true)
        } else {
            try db.collection(collection).addDocument(from: data)
        }
    }
}
