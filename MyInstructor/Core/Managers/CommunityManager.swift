// File: arafatrahman/myinstructor/MyInstructor-main/MyInstructor/Core/Managers/CommunityManager.swift
import Combine
import Foundation
import FirebaseFirestore

class CommunityManager: ObservableObject {
    private let db = Firestore.firestore()
    private var postsCollection: CollectionReference {
        db.collection("community_posts")
    }
    private var usersCollection: CollectionReference {
        db.collection("users")
    }
    // --- ADD THIS ---
    private var requestsCollection: CollectionReference {
        db.collection("student_requests")
    }

    // Fetches recent community posts based on filters
    func fetchPosts(filter: String) async throws -> [Post] {
        // TODO: Implement actual filter logic based on the 'filter' string.
        // This example just fetches the 20 newest posts.
        let snapshot = try await postsCollection
            .order(by: "timestamp", descending: true)
            .limit(to: 20)
            .getDocuments()
        
        // Use compactMap to safely decode posts
        let posts = snapshot.documents.compactMap { document in
            try? document.data(as: Post.self)
        }
        return posts
    }
    
    func createPost(post: Post) async throws {
        // Use `addDocument(from:)` to encode the Post object
        try postsCollection.addDocument(from: post)
        print("Post created successfully by \(post.authorName)")
    }

    // Fetches instructors from the 'users' collection
    func fetchInstructorDirectory(filters: [String: Any]) async throws -> [Student] {
        // TODO: Implement advanced filtering based on the 'filters' dictionary.
        // This example just fetches all users marked as 'instructor'.
        let snapshot = try await usersCollection
            .whereField("role", isEqualTo: UserRole.instructor.rawValue)
            .limit(to: 20) // Consider pagination for larger sets
            .getDocuments()
            
        // We are mapping AppUser data to the Student model for the directory list.
        let instructors = snapshot.documents.compactMap { document -> Student? in
            guard let appUser = try? document.data(as: AppUser.self) else { return nil }
            // Create a 'Student' object from the 'AppUser' data for the directory list
            return Student(
                id: appUser.id,
                userID: appUser.id ?? "unknown_user_id",
                name: appUser.name ?? "Instructor",
                photoURL: appUser.photoURL,
                email: appUser.email,
                drivingSchool: appUser.drivingSchool,
                // --- *** ADDED THESE FIELDS *** ---
                phone: appUser.phone,
                address: appUser.address
                // distance will be nil by default, calculated in the view
            )
        }
        return instructors
    }
    
    // MARK: - --- STUDENT REQUEST FUNCTIONS ---
    
    // --- 1. NEW FUNCTION (Called by Student) ---
    func sendRequest(from student: AppUser, to instructorID: String) async throws {
        guard let studentID = student.id else { throw URLError(.badServerResponse) }
        
        // Check if a request already exists
        let existing = try await requestsCollection
            .whereField("studentID", isEqualTo: studentID)
            .whereField("instructorID", isEqualTo: instructorID)
            .getDocuments()
            
        guard existing.isEmpty else {
            print("Request already sent.")
            return
        }

        let newRequest = StudentRequest(
            studentID: studentID,
            studentName: student.name ?? "New Student",
            studentPhotoURL: student.photoURL,
            instructorID: instructorID,
            status: .pending,
            timestamp: Date()
        )
        
        try requestsCollection.addDocument(from: newRequest)
    }

    // --- 2. NEW FUNCTION (Called by Instructor) ---
    func fetchRequests(for instructorID: String) async throws -> [StudentRequest] {
        let snapshot = try await requestsCollection
            .whereField("instructorID", isEqualTo: instructorID)
            .whereField("status", isEqualTo: RequestStatus.pending.rawValue)
            .order(by: "timestamp", descending: true)
            .getDocuments()
            
        return snapshot.documents.compactMap { try? $0.data(as: StudentRequest.self) }
    }
    
    // --- 3. NEW FUNCTION (Called by Instructor) ---
    func approveRequest(_ request: StudentRequest) async throws {
        guard let requestID = request.id else { throw URLError(.badServerResponse) }
        
        // Use a batch write to make this transactional
        let batch = db.batch()
        
        // 1. Update the request status to "approved"
        let requestRef = requestsCollection.document(requestID)
        batch.updateData(["status": RequestStatus.approved.rawValue], forDocument: requestRef)
        
        // 2. Add studentID to instructor's 'studentIDs' array
        let instructorRef = usersCollection.document(request.instructorID)
        batch.updateData(["studentIDs": FieldValue.arrayUnion([request.studentID])], forDocument: instructorRef)
        
        // 3. Add instructorID to student's 'instructorIDs' array
        let studentRef = usersCollection.document(request.studentID)
        batch.updateData(["instructorIDs": FieldValue.arrayUnion([request.instructorID])], forDocument: studentRef)
        
        // Commit the batch
        try await batch.commit()
    }
    
    // --- 4. NEW FUNCTION (Called by Instructor) ---
    func denyRequest(_ request: StudentRequest) async throws {
        guard let requestID = request.id else { throw URLError(.badServerResponse) }
        try await requestsCollection.document(requestID).updateData(["status": RequestStatus.denied.rawValue])
    }
}
