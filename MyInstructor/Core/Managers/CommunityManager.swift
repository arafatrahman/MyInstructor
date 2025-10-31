// File: arafatrahman/myinstructor/MyInstructor-main/MyInstructor/Core/Managers/CommunityManager.swift
// --- UPDATED with 'removeInstructor' function ---

import Combine
import Foundation
import FirebaseFirestore

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
    private var conversationsCollection: CollectionReference {
        db.collection("conversations")
    }

    // Fetches recent community posts
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

    func fetchRequests(for instructorID: String) async throws -> [StudentRequest] {
        let snapshot = try await requestsCollection
            .whereField("instructorID", isEqualTo: instructorID)
            .whereField("status", isEqualTo: RequestStatus.pending.rawValue)
            .order(by: "timestamp", descending: true)
            .getDocuments()
            
        return snapshot.documents.compactMap { try? $0.data(as: StudentRequest.self) }
    }
    
    func approveRequest(_ request: StudentRequest) async throws {
        guard let requestID = request.id else { throw URLError(.badServerResponse) }
        
        let instructorDoc = try await usersCollection.document(request.instructorID).getDocument()
        guard let instructor = try? instructorDoc.data(as: AppUser.self) else {
            throw URLError(.cannotFindHost)
        }

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
        
        let batch = db.batch()
        
        let requestRef = requestsCollection.document(requestID)
        batch.updateData(["status": RequestStatus.approved.rawValue], forDocument: requestRef)
        
        let instructorRef = usersCollection.document(request.instructorID)
        batch.updateData(["studentIDs": FieldValue.arrayUnion([request.studentID])], forDocument: instructorRef)
        
        // --- ADD STUDENT TO INSTRUCTOR ID LIST (FOR STUDENT'S APP) ---
        let studentRef = usersCollection.document(request.studentID)
        batch.updateData(["instructorIDs": FieldValue.arrayUnion([request.instructorID])], forDocument: studentRef)
        // --- END OF CHANGE ---
        
        let conversationRef = conversationsCollection.document()
        try batch.setData(from: newConversation, forDocument: conversationRef)
        
        try await batch.commit()
    }
    
    func denyRequest(_ request: StudentRequest) async throws {
        guard let requestID = request.id else { throw URLError(.badServerResponse) }
        try await requestsCollection.document(requestID).updateData(["status": RequestStatus.denied.rawValue])
    }
    
    func removeStudent(studentID: String, instructorID: String) async throws {
        let batch = db.batch()
        
        let instructorRef = usersCollection.document(instructorID)
        batch.updateData(["studentIDs": FieldValue.arrayRemove([studentID])], forDocument: instructorRef)
        
        // --- ADDED: Also remove instructor from student's list ---
        let studentRef = usersCollection.document(studentID)
        batch.updateData(["instructorIDs": FieldValue.arrayRemove([instructorID])], forDocument: studentRef)
        // --- END OF CHANGE ---
        
        let requestQuery = try await requestsCollection
            .whereField("studentID", isEqualTo: studentID)
            .whereField("instructorID", isEqualTo: instructorID)
            .whereField("status", isEqualTo: RequestStatus.approved.rawValue)
            .getDocuments()
        
        for doc in requestQuery.documents {
            batch.updateData(["status": RequestStatus.denied.rawValue], forDocument: doc.reference)
        }
        
        try await batch.commit()
    }
    
    // --- *** NEW FUNCTION: Called by Student "Remove" button *** ---
    func removeInstructor(instructorID: String, studentID: String) async throws {
        let batch = db.batch()
        
        // 1. Remove instructor from student's list
        let studentRef = usersCollection.document(studentID)
        batch.updateData(["instructorIDs": FieldValue.arrayRemove([instructorID])], forDocument: studentRef)
        
        // 2. Remove student from instructor's list
        let instructorRef = usersCollection.document(instructorID)
        batch.updateData(["studentIDs": FieldValue.arrayRemove([studentID])], forDocument: instructorRef)
        
        // 3. Find and update the request to 'denied'
        let requestQuery = try await requestsCollection
            .whereField("studentID", isEqualTo: studentID)
            .whereField("instructorID", isEqualTo: instructorID)
            .whereField("status", isEqualTo: RequestStatus.approved.rawValue)
            .getDocuments()
        
        for doc in requestQuery.documents {
            batch.updateData(["status": RequestStatus.denied.rawValue], forDocument: doc.reference)
        }
        
        try await batch.commit()
    }
    
    func fetchSentRequests(for studentID: String) async throws -> [StudentRequest] {
        let snapshot = try await requestsCollection
            .whereField("studentID", isEqualTo: studentID)
            .order(by: "timestamp", descending: true)
            .getDocuments()
            
        return snapshot.documents.compactMap { try? $0.data(as: StudentRequest.self) }
    }
    
    func cancelRequest(requestID: String) async throws {
        try await requestsCollection.document(requestID).delete()
    }
}
