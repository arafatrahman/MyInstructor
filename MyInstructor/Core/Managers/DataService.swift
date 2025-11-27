// File: arafatrahman/myinstructor/MyInstructor-main/MyInstructor/Core/Managers/DataService.swift
import Foundation
import Combine
import FirebaseFirestore

class DataService: ObservableObject {
    
    private let db = Firestore.firestore()
    private var usersCollection: CollectionReference {
        db.collection("users")
    }
    private var lessonsCollection: CollectionReference {
        db.collection("lessons")
    }
    private var offlineStudentsCollection: CollectionReference {
        db.collection("offline_students")
    }
    
    init() {}
    
    // MARK: - Dashboard Data Fetching
    
    func fetchInstructorDashboardData(for instructorID: String) async throws -> (nextLesson: Lesson?, earnings: Double, avgProgress: Double) {
        // 1. Fetch Next Lesson
        let lessonSnapshot = try await lessonsCollection
            .whereField("instructorID", isEqualTo: instructorID)
            .whereField("status", isEqualTo: LessonStatus.scheduled.rawValue)
            .whereField("startTime", isGreaterThan: Date())
            .order(by: "startTime")
            .limit(to: 1)
            .getDocuments()
            
        let nextLesson = try? lessonSnapshot.documents.first?.data(as: Lesson.self)
        
        // 2. Calculate Average Progress (Online + Offline)
        var allProgressValues: [Double] = []
        
        // A. Online Students
        let onlineRecordsSnapshot = try await usersCollection
            .document(instructorID)
            .collection("student_records")
            .getDocuments()
        
        let onlineProgress = onlineRecordsSnapshot.documents.compactMap { doc -> Double? in
            return try? doc.data(as: StudentRecord.self).progress
        }
        allProgressValues.append(contentsOf: onlineProgress)
        
        // B. Offline Students
        let offlineStudentsSnapshot = try await offlineStudentsCollection
            .whereField("instructorID", isEqualTo: instructorID)
            .getDocuments()
            
        let offlineProgress = offlineStudentsSnapshot.documents.compactMap { doc -> Double? in
            return try? doc.data(as: OfflineStudent.self).progress
        }
        allProgressValues.append(contentsOf: offlineProgress)
        
        // Calculate Average
        let avgProgress = allProgressValues.isEmpty ? 0.0 : allProgressValues.reduce(0, +) / Double(allProgressValues.count)
        
        return (nextLesson, 0.0, avgProgress)
    }

    func fetchStudentDashboardData(for studentID: String) async throws -> (upcomingLesson: Lesson?, progress: Double, latestFeedback: String, paymentDue: Bool) {
        let lessonSnapshot = try await lessonsCollection
            .whereField("studentID", isEqualTo: studentID)
            .whereField("status", isEqualTo: LessonStatus.scheduled.rawValue)
            .whereField("startTime", isGreaterThan: Date())
            .order(by: "startTime")
            .limit(to: 1)
            .getDocuments()
            
        let upcomingLesson = try? lessonSnapshot.documents.first?.data(as: Lesson.self)
        return (upcomingLesson, 0.0, "", false)
    }
    
    // MARK: - User Management Fetching
    
    // Fetches ONLINE students only
    func fetchStudents(for instructorID: String) async throws -> [Student] {
        let instructorDoc = try await usersCollection.document(instructorID).getDocument()
        guard let instructor = try? instructorDoc.data(as: AppUser.self) else { return [] }
        guard let studentIDs = instructor.studentIDs, !studentIDs.isEmpty else { return [] }
        
        let studentQuery = try await usersCollection.whereField(FieldPath.documentID(), in: studentIDs).getDocuments()
        let recordsQuery = try await usersCollection.document(instructorID).collection("student_records").getDocuments()
            
        var progressMap: [String: Double] = [:]
        for doc in recordsQuery.documents {
            if let record = try? doc.data(as: StudentRecord.self), let id = record.id {
                progressMap[id] = record.progress ?? 0.0
            }
        }
            
        let students = studentQuery.documents.compactMap { document -> Student? in
            guard let appUser = try? document.data(as: AppUser.self) else { return nil }
            let uid = appUser.id ?? ""
            return Student(
                id: uid,
                userID: uid,
                name: appUser.name ?? "Student",
                photoURL: appUser.photoURL,
                email: appUser.email,
                drivingSchool: appUser.drivingSchool,
                phone: appUser.phone,
                address: appUser.address,
                averageProgress: progressMap[uid] ?? 0.0
            )
        }
        return students
    }
    
    // Fetches OFFLINE students only
    func fetchOfflineStudents(for instructorID: String) async throws -> [OfflineStudent] {
        let snapshot = try await offlineStudentsCollection
            .whereField("instructorID", isEqualTo: instructorID)
            .order(by: "name")
            .getDocuments()
            
        let students = snapshot.documents.compactMap { document -> OfflineStudent? in
            try? document.data(as: OfflineStudent.self)
        }
        return students
    }
    
    // --- NEW: Fetches BOTH and unifies them into [Student] ---
    func fetchAllStudents(for instructorID: String) async throws -> [Student] {
        async let onlineTask = fetchStudents(for: instructorID)
        async let offlineTask = fetchOfflineStudents(for: instructorID)
        
        let online = try await onlineTask
        let offline = try await offlineTask
        
        // Convert offline to Student struct
        let convertedOffline = offline.map { off -> Student in
            return Student(
                id: off.id,
                userID: off.id ?? UUID().uuidString,
                name: off.name,
                photoURL: nil,
                email: off.email ?? "",
                drivingSchool: nil,
                phone: off.phone,
                address: off.address,
                isOffline: true,
                averageProgress: off.progress ?? 0.0
            )
        }
        
        return (online + convertedOffline).sorted { $0.name < $1.name }
    }
    
    func fetchUser(withId userID: String) async throws -> AppUser? {
        let doc = try await usersCollection.document(userID).getDocument()
        return try doc.data(as: AppUser.self)
    }
    
    // --- NEW: Resolves name for PaymentCard (checks online then offline) ---
    func resolveStudentName(studentID: String) async -> String {
        // 1. Try Online
        if let userDoc = try? await usersCollection.document(studentID).getDocument(),
           userDoc.exists,
           let user = try? userDoc.data(as: AppUser.self) {
            return user.name ?? "Student"
        }
        
        // 2. Try Offline
        if let offlineDoc = try? await offlineStudentsCollection.document(studentID).getDocument(),
           offlineDoc.exists,
           let offlineStudent = try? offlineDoc.data(as: OfflineStudent.self) {
            return offlineStudent.name
        }
        
        return "Unknown Student"
    }
    
    // Synchronous helper (deprecated for async views, kept for safety)
    func getStudentName(for studentID: String) -> String {
        return "Loading..."
    }
}
