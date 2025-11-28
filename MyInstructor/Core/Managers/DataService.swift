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
    
    // MARK: - Dashboard Data Fetching (Instructor)
    
    func fetchInstructorDashboardData(for instructorID: String) async throws -> (nextLesson: Lesson?, earnings: Double, avgProgress: Double) {
        let lessonSnapshot = try await lessonsCollection
            .whereField("instructorID", isEqualTo: instructorID)
            .whereField("status", isEqualTo: LessonStatus.scheduled.rawValue)
            .getDocuments()
            
        let lessons = lessonSnapshot.documents.compactMap { try? $0.data(as: Lesson.self) }
        let nextLesson = lessons.filter { $0.startTime > Date() }.sorted(by: { $0.startTime < $1.startTime }).first
        
        var allProgressValues: [Double] = []
        
        let onlineRecordsSnapshot = try await usersCollection.document(instructorID).collection("student_records").getDocuments()
        let onlineProgress = onlineRecordsSnapshot.documents.compactMap { try? $0.data(as: StudentRecord.self).progress }
        allProgressValues.append(contentsOf: onlineProgress)
        
        let offlineStudentsSnapshot = try await offlineStudentsCollection.whereField("instructorID", isEqualTo: instructorID).getDocuments()
        let offlineProgress = offlineStudentsSnapshot.documents.compactMap { try? $0.data(as: OfflineStudent.self).progress }
        allProgressValues.append(contentsOf: offlineProgress)
        
        let avgProgress = allProgressValues.isEmpty ? 0.0 : allProgressValues.reduce(0, +) / Double(allProgressValues.count)
        
        return (nextLesson, 0.0, avgProgress)
    }

    // MARK: - Dashboard Data Fetching (Student)
    
    func fetchStudentDashboardData(for studentID: String) async throws -> (upcomingLesson: Lesson?, progress: Double, latestFeedback: String, paymentDue: Bool) {
        // 1. Fetch Upcoming Lesson
        let lessonSnapshot = try await lessonsCollection
            .whereField("studentID", isEqualTo: studentID)
            .whereField("status", isEqualTo: LessonStatus.scheduled.rawValue)
            .getDocuments()
            
        let lessons = lessonSnapshot.documents.compactMap { try? $0.data(as: Lesson.self) }
        let upcomingLesson = lessons.filter { $0.startTime > Date() }.sorted(by: { $0.startTime < $1.startTime }).first
        
        // 2. Fetch Progress & Feedback
        // Get ALL instructor IDs associated with this student via requests
        let requestsQuery = try await db.collection("student_requests")
            .whereField("studentID", isEqualTo: studentID)
            .getDocuments()
            
        // Use Set to avoid duplicates
        let instructorIDs = Set(requestsQuery.documents.compactMap { $0.data()["instructorID"] as? String })
        
        var totalProgress: Double = 0.0
        var count: Int = 0
        var latestNoteContent: String = ""
        var latestNoteDate: Date = Date.distantPast
        
        for instructorID in instructorIDs {
            let recordDoc = try? await usersCollection
                .document(instructorID)
                .collection("student_records")
                .document(studentID)
                .getDocument()
            
            if let record = try? recordDoc?.data(as: StudentRecord.self) {
                // Progress
                if let p = record.progress {
                    totalProgress += p
                    count += 1
                }
                
                // Notes - Find the absolute newest note
                if let notes = record.notes, !notes.isEmpty {
                    if let newestInRecord = notes.sorted(by: { $0.timestamp < $1.timestamp }).last {
                        if newestInRecord.timestamp > latestNoteDate {
                            latestNoteDate = newestInRecord.timestamp
                            latestNoteContent = newestInRecord.content
                        }
                    }
                }
            }
        }
        
        let avgProgress = count > 0 ? totalProgress / Double(count) : 0.0
        
        return (upcomingLesson, avgProgress, latestNoteContent, false)
    }
    
    // --- NEW FUNCTION: Fetch all notes for a student ---
    func fetchAllStudentNotes(for studentID: String) async throws -> [StudentNote] {
        // Get ALL instructor IDs associated with this student via requests
        let requestsQuery = try await db.collection("student_requests")
            .whereField("studentID", isEqualTo: studentID)
            .getDocuments()
            
        // Use Set to avoid duplicates
        let instructorIDs = Set(requestsQuery.documents.compactMap { $0.data()["instructorID"] as? String })
        
        var allNotes: [StudentNote] = []
        
        for instructorID in instructorIDs {
            let recordDoc = try? await usersCollection
                .document(instructorID)
                .collection("student_records")
                .document(studentID)
                .getDocument()
            
            if let record = try? recordDoc?.data(as: StudentRecord.self), let notes = record.notes {
                allNotes.append(contentsOf: notes)
            }
        }
        
        // Return sorted by date (newest first)
        return allNotes.sorted(by: { $0.timestamp > $1.timestamp })
    }
    
    // MARK: - User Management Fetching (Helper Methods)
    
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
            
        return studentQuery.documents.compactMap { document -> Student? in
            guard let appUser = try? document.data(as: AppUser.self) else { return nil }
            let uid = appUser.id ?? ""
            return Student(
                id: uid, userID: uid, name: appUser.name ?? "Student",
                photoURL: appUser.photoURL, email: appUser.email,
                drivingSchool: appUser.drivingSchool, phone: appUser.phone,
                address: appUser.address, averageProgress: progressMap[uid] ?? 0.0
            )
        }
    }
    
    func fetchOfflineStudents(for instructorID: String) async throws -> [OfflineStudent] {
        let snapshot = try await offlineStudentsCollection.whereField("instructorID", isEqualTo: instructorID).getDocuments()
        return snapshot.documents.compactMap { try? $0.data(as: OfflineStudent.self) }
    }
    
    func fetchAllStudents(for instructorID: String) async throws -> [Student] {
        async let online = fetchStudents(for: instructorID)
        async let offline = fetchOfflineStudents(for: instructorID)
        
        let convertedOffline = try await offline.map { off -> Student in
            Student(id: off.id, userID: off.id ?? UUID().uuidString, name: off.name, photoURL: nil, email: off.email ?? "", drivingSchool: nil, phone: off.phone, address: off.address, isOffline: true, averageProgress: off.progress ?? 0.0)
        }
        return (try await online + convertedOffline).sorted { $0.name < $1.name }
    }
    
    func fetchUser(withId userID: String) async throws -> AppUser? {
        let doc = try await usersCollection.document(userID).getDocument()
        return try doc.data(as: AppUser.self)
    }
    
    func resolveStudentName(studentID: String) async -> String {
        if let user = try? await fetchUser(withId: studentID) { return user.name ?? "Student" }
        if let offlineDoc = try? await offlineStudentsCollection.document(studentID).getDocument(), let off = try? offlineDoc.data(as: OfflineStudent.self) { return off.name }
        return "Unknown Student"
    }
    
    func getStudentName(for studentID: String) -> String { return "Loading..." }
}
