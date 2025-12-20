import Foundation
import FirebaseFirestore
class DummyDataManager {
    static let shared = DummyDataManager()
    private let db = Firestore.firestore()
    
    private init() {}
    
    func generateDummyData(for instructorID: String) async throws {
        print("--- STARTING DUMMY DATA GENERATION ---")
        
        // 1. Create Offline Students
        let studentIDs = try await createDummyStudents(instructorID: instructorID)
        
        // 2. Create Content for each Student
        for studentID in studentIDs {
            try await createDummyLessons(instructorID: instructorID, studentID: studentID)
            try await createDummyPayments(instructorID: instructorID, studentID: studentID)
            try await createDummyExams(instructorID: instructorID, studentID: studentID)
        }
        
        // 3. Create General Instructor Data
        try await createDummyExpenses(instructorID: instructorID)
        try await createDummyVehicles(instructorID: instructorID)
        try await createDummyContacts(instructorID: instructorID)
        
        print("--- DUMMY DATA GENERATION COMPLETE ---")
    }
    
    // MARK: - Students
    private func createDummyStudents(instructorID: String) async throws -> [String] {
        let names = ["Alice Walker", "Bob Smith", "Charlie Brown", "Daisy Miller"]
        var ids: [String] = []
        
        for name in names {
            let id = UUID().uuidString
            let student = OfflineStudent(
                id: id,
                instructorID: instructorID,
                name: name,
                phone: "07700900\(Int.random(in: 100...999))",
                email: "\(name.lowercased().replacingOccurrences(of: " ", with: "."))@example.com",
                address: "\(Int.random(in: 1...100)) High Street, London",
                progress: Double.random(in: 0.1...0.9)
            )
            try db.collection("offline_students").document(id).setData(from: student)
            ids.append(id)
        }
        return ids
    }
    
    // MARK: - Lessons
    private func createDummyLessons(instructorID: String, studentID: String) async throws {
        // Past Lesson
        let pastLesson = Lesson(
            id: UUID().uuidString,
            instructorID: instructorID,
            studentID: studentID,
            topic: "Roundabouts",
            startTime: Date().addingTimeInterval(-86400 * 3), // 3 days ago
            duration: 7200, // 2 hours
            pickupLocation: "Home",
            fee: 60.0,
            notes: "Good progress on lane discipline.",
            status: .completed
        )
        try db.collection("lessons").document(pastLesson.id!).setData(from: pastLesson)
        
        // Future Lesson
        let futureLesson = Lesson(
            id: UUID().uuidString,
            instructorID: instructorID,
            studentID: studentID,
            topic: "Dual Carriageways",
            startTime: Date().addingTimeInterval(86400 * 2), // 2 days later
            duration: 3600, // 1 hour
            pickupLocation: "Test Center",
            fee: 35.0,
            notes: nil,
            status: .scheduled
        )
        try db.collection("lessons").document(futureLesson.id!).setData(from: futureLesson)
    }
    
    // MARK: - Payments
    private func createDummyPayments(instructorID: String, studentID: String) async throws {
        let payment = Payment(
            id: UUID().uuidString,
            instructorID: instructorID,
            studentID: studentID,
            amount: 300.0,
            date: Date().addingTimeInterval(-86400 * 5),
            isPaid: true,
            paymentMethod: .bankTransfer,
            note: "Block booking payment (10 hours)",
            hours: 10.0
        )
        try db.collection("payments").document(payment.id!).setData(from: payment)
    }
    
    // MARK: - Exams
    private func createDummyExams(instructorID: String, studentID: String) async throws {
        // Only add exams for some students
        if Bool.random() {
            let exam = ExamResult(
                id: UUID().uuidString,
                studentID: studentID,
                instructorID: instructorID,
                date: Date().addingTimeInterval(86400 * 14), // 2 weeks away
                testCenter: "Wood Green",
                status: .scheduled
            )
            try db.collection("exam_results").document(exam.id!).setData(from: exam)
        }
    }
    
    // MARK: - Expenses
    private func createDummyExpenses(instructorID: String) async throws {
        let expenses = [
            Expense(id: UUID().uuidString, instructorID: instructorID, title: "Petrol", amount: 45.50, date: Date(), category: .fuel, note: "Full tank"),
            Expense(id: UUID().uuidString, instructorID: instructorID, title: "Car Wash", amount: 15.00, date: Date().addingTimeInterval(-86400), category: .maintenance, note: nil)
        ]
        
        for expense in expenses {
            try db.collection("expenses").document(expense.id!).setData(from: expense)
        }
    }
    
    // MARK: - Vehicles
    private func createDummyVehicles(instructorID: String) async throws {
        let vehicleID = UUID().uuidString
        let vehicle = Vehicle(
            id: vehicleID,
            instructorID: instructorID,
            make: "Toyota",
            model: "Yaris",
            year: "2021",
            licensePlate: "AB21 CDE",
            nickname: "Red Yaris",
            insuranceExpiry: Date().addingTimeInterval(86400 * 180),
            motExpiry: Date().addingTimeInterval(86400 * 200)
        )
        try db.collection("vehicles").document(vehicleID).setData(from: vehicle)
        
        // Service Record
        let service = ServiceRecord(
            id: UUID().uuidString,
            instructorID: instructorID,
            vehicleID: vehicleID,
            date: Date().addingTimeInterval(-86400 * 30),
            mileage: 15000,
            serviceType: "Oil Change",
            garageName: "KwikFit",
            cost: 80.0,
            notes: nil,
            nextServiceDate: Date().addingTimeInterval(86400 * 330)
        )
        try db.collection("vehicle_services").document(service.id!).setData(from: service)
        
        // Mileage Log
        let log = MileageLog(
            id: UUID().uuidString,
            instructorID: instructorID,
            vehicleID: vehicleID,
            date: Date(),
            startReading: 15100,
            endReading: 15150,
            purpose: "Lessons",
            notes: "Morning lessons"
        )
        try db.collection("mileage_logs").document(log.id!).setData(from: log)
    }
    
    // MARK: - Contacts
    private func createDummyContacts(instructorID: String) async throws {
        let contact = CustomContact(
            id: UUID().uuidString,
            instructorID: instructorID,
            name: "Local Garage",
            phone: "020 7946 0000",
            email: "service@garage.com",
            note: "Ask for Mike"
        )
        try db.collection("users").document(instructorID).collection("custom_contacts").document(contact.id!).setData(from: contact)
    }
}
