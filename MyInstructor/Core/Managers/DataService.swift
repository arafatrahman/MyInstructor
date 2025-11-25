// File: arafatrahman/myinstructor/MyInstructor-main/MyInstructor/Core/Managers/DataService.swift
// --- UPDATED: Properly fetches progress for Student List and Dashboard averages ---

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
        
        // A. Online Students (from subcollection)
        // Note: Requires the Firestore rule for 'student_records' to be set
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
        
        // 3. Earnings (Placeholder for now)
        // In a real app, you'd fetch payments here
        
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
        
        // Note: Student dashboard progress usually comes from the instructor's record.
        // Ideally, we need to know *which* instructor's progress to show if they have multiple.
        // For simplicity, this returns 0.0 unless we pass an instructor ID or query differently.
        
        return (upcomingLesson, 0.0, "", false)
    }
    
    // MARK: - User Management Fetching
    
    func fetchStudents(for instructorID: String) async throws -> [Student] {
        // 1. Get Instructor Document to find linked Student IDs
        let instructorDoc = try await usersCollection.document(instructorID).getDocument()
        guard let instructor = try? instructorDoc.data(as: AppUser.self) else { return [] }
        
        guard let studentIDs = instructor.studentIDs, !studentIDs.isEmpty else { return [] }
        
        // 2. Fetch User Profiles
        let studentQuery = try await usersCollection
            .whereField(FieldPath.documentID(), in: studentIDs)
            .getDocuments()
        
        // 3. Fetch Progress Records (to map mastery %)
        // We fetch the entire subcollection once to avoid N+1 queries
        let recordsQuery = try await usersCollection
            .document(instructorID)
            .collection("student_records")
            .getDocuments()
            
        // Create a dictionary [StudentID: Progress]
        var progressMap: [String: Double] = [:]
        for doc in recordsQuery.documents {
            if let record = try? doc.data(as: StudentRecord.self), let id = record.id {
                progressMap[id] = record.progress ?? 0.0
            }
        }
            
        // 4. Merge Data
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
                averageProgress: progressMap[uid] ?? 0.0 // Inject progress from map
            )
        }
        
        return students
    }
    
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
    
    func fetchUser(withId userID: String) async throws -> AppUser? {
        let doc = try await usersCollection.document(userID).getDocument()
        return try doc.data(as: AppUser.self)
    }
    
    func fetchInstructors(for studentID: String) async throws -> [AppUser] {
        let studentDoc = try await usersCollection.document(studentID).getDocument()
        guard let student = try? studentDoc.data(as: AppUser.self) else { return [] }
        guard let instructorIDs = student.instructorIDs, !instructorIDs.isEmpty else { return [] }
        
        let instructorQuery = try await usersCollection
            .whereField(FieldPath.documentID(), in: instructorIDs)
            .getDocuments()
            
        return instructorQuery.documents.compactMap { doc in
            try? doc.data(as: AppUser.self)
        }
    }
    
    func getStudentName(for studentID: String) -> String {
        return "Unknown Student"
    }
}
