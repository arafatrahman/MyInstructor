// File: arafatrahman/myinstructor/MyInstructor-main/MyInstructor/Core/Managers/CommunityManager.swift
// --- UPDATED to create a chat channel on approve ---

import Combine
import Foundation
import FirebaseFirestore

// --- NEW: Define custom errors for the UI ---
enum RequestError: Error, LocalizedError {
    case alreadyPending
    case alreadyApproved
    
    var errorDescription: String? {
        switch self {
        case .alreadyPending:
            return "A request is already pending with this instructor."
        case .alreadyApproved:
            return "You are already an approved student of this instructor."
        }
    }
}


class CommunityManager: ObservableObject {
    private let db = Firestore.firestore()
    private var postsCollection: CollectionReference {
        db.collection("community_posts")
    }
    private var usersCollection: CollectionReference {
        db.collection("users")
    }
    private var requestsCollection: CollectionReference {
        db.collection("student_requests")
    }
    
    // --- *** ADD THIS *** ---
    private var conversationsCollection: CollectionReference {
        db.collection("conversations")
    }

    // Fetches recent community posts based on filters
    func fetchPosts(filter: String) async throws -> [Post] {
        let snapshot = try await postsCollection
            .order(by: "timestamp", descending: true)
            .limit(to: 20)
            .getDocuments()
        
        let posts = snapshot.documents.compactMap { document in
            try? document.data(as: Post.self)
        }
        return posts
    }
    
    func createPost(post: Post) async throws {
        try postsCollection.addDocument(from: post)
    }

    // Fetches instructors from the 'users' collection
    func fetchInstructorDirectory(filters: [String: Any]) async throws -> [Student] {
        let snapshot = try await usersCollection
            .whereField("role", isEqualTo: UserRole.instructor.rawValue)
            .limit(to: 20)
            .getDocuments()
            
        let instructors = snapshot.documents.compactMap { document -> Student? in
            guard let appUser = try? document.data(as: AppUser.self) else { return nil }
            return Student(
                id: appUser.id,
                userID: appUser.id ?? "unknown_user_id",
                name: appUser.name ?? "Instructor",
                photoURL: appUser.photoURL,
                email: appUser.email,
                drivingSchool: appUser.drivingSchool,
                phone: appUser.phone,
                address: appUser.address
            )
        }
        return instructors
    }
    
    // MARK: - --- STUDENT REQUEST FUNCTIONS ---
    
    // --- 1. Called by Student (FIXED) ---
    func sendRequest(from student: AppUser, to instructorID: String) async throws {
        guard let studentID = student.id else { throw URLError(.badServerResponse) }
        
        let existingQuery = try await requestsCollection
            .whereField("studentID", isEqualTo: studentID)
            .whereField("instructorID", isEqualTo: instructorID)
            .getDocuments()

        for doc in existingQuery.documents {
            if let status = doc.data()["status"] as? String {
                if status == RequestStatus.pending.rawValue {
                    print("Request already pending.")
                    throw RequestError.alreadyPending
                }
                if status == RequestStatus.approved.rawValue {
                    print("Student is already approved by this instructor.")
                    throw RequestError.alreadyApproved
                }
                if status == RequestStatus.denied.rawValue {
                    print("Found a denied request. Deleting it to re-apply...")
                    try await doc.reference.delete()
                    print("Old request deleted.")
                }
            }
        }
        
        print("Creating new request...")
        let newRequest = StudentRequest(
            studentID: studentID,
            studentName: student.name ?? "New Student",
            studentPhotoURL: student.photoURL,
            instructorID: instructorID,
            status: .pending,
            timestamp: Date()
        )
        
        try requestsCollection.addDocument(from: newRequest)
        print("New request sent successfully.")
    }

    // --- 2. Called by Instructor (StudentsListView) ---
    func fetchRequests(for instructorID: String) async throws -> [StudentRequest] {
        let snapshot = try await requestsCollection
            .whereField("instructorID", isEqualTo: instructorID)
            .whereField("status", isEqualTo: RequestStatus.pending.rawValue)
            .order(by: "timestamp", descending: true)
            .getDocuments()
            
        return snapshot.documents.compactMap { try? $0.data(as: StudentRequest.self) }
    }
    
    // --- 3. Called by Instructor (Approve Button) ---
    // --- *** THIS FUNCTION IS NOW UPDATED *** ---
    func approveRequest(_ request: StudentRequest) async throws {
        guard let requestID = request.id else { throw URLError(.badServerResponse) }
        
        // --- 1. Get Instructor's user data for the chat ---
        let instructorDoc = try await usersCollection.document(request.instructorID).getDocument()
        guard let instructor = try? instructorDoc.data(as: AppUser.self) else {
            throw URLError(.cannotFindHost) // Can't find instructor
        }

        // --- 2. Create the new Conversation object ---
        let newConversation = Conversation(
            participantIDs: [request.studentID, request.instructorID],
            participantNames: [
                request.studentID: request.studentName,
                request.instructorID: instructor.name ?? "Instructor"
            ],
            participantPhotoURLs: [
                request.studentID: request.studentPhotoURL,
                request.instructorID: instructor.photoURL
            ],
            lastMessage: "You are now connected!",
            lastMessageTimestamp: Date()
        )
        
        // --- 3. Use a batch write to do everything at once ---
        let batch = db.batch()
        
        // 3a. Update the request status
        let requestRef = requestsCollection.document(requestID)
        batch.updateData(["status": RequestStatus.approved.rawValue], forDocument: requestRef)
        
        // 3b. Add studentID to instructor's 'studentIDs' array
        let instructorRef = usersCollection.document(request.instructorID)
        batch.updateData(["studentIDs": FieldValue.arrayUnion([request.studentID])], forDocument: instructorRef)
        
        // 3c. Create the new conversation document
        let conversationRef = conversationsCollection.document()
        try batch.setData(from: newConversation, forDocument: conversationRef)
        
        // 3d. Commit the batch
        try await batch.commit()
    }
    
    // --- 4. Called by Instructor (Deny Button) ---
    func denyRequest(_ request: StudentRequest) async throws {
        guard let requestID = request.id else { throw URLError(.badServerResponse) }
        try await requestsCollection.document(requestID).updateData(["status": RequestStatus.denied.rawValue])
    }
    
    // --- 5. Called by Instructor ("Remove" button) ---
    func removeStudent(studentID: String, instructorID: String) async throws {
        let batch = db.batch()
        
        let instructorRef = usersCollection.document(instructorID)
        batch.updateData(["studentIDs": FieldValue.arrayRemove([studentID])], forDocument: instructorRef)
        
        let requestQuery = try await requestsCollection
            .whereField("studentID", isEqualTo: studentID)
            .whereField("instructorID", isEqualTo: instructorID)
            .whereField("status", isEqualTo: RequestStatus.approved.rawValue)
            .getDocuments()
        
        for doc in requestQuery.documents {
            batch.updateData(["status": RequestStatus.denied.rawValue], forDocument: doc.reference)
        }
        
        // TODO: You may also want to delete the 'conversation' document here
        
        try await batch.commit()
    }
    
    // --- 6. Called by Student (MyInstructorsView) ---
    func fetchSentRequests(for studentID: String) async throws -> [StudentRequest] {
        let snapshot = try await requestsCollection
            .whereField("studentID", isEqualTo: studentID)
            .order(by: "timestamp", descending: true)
            .getDocuments()
            
        return snapshot.documents.compactMap { try? $0.data(as: StudentRequest.self) }
    }
    
    // --- 7. Called by Student "Cancel" button ---
    func cancelRequest(requestID: String) async throws {
        try await requestsCollection.document(requestID).delete()
    }
}
