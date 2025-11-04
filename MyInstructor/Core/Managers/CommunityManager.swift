// File: arafatrahman/myinstructor/MyInstructor-main/MyInstructor/Core/Managers/CommunityManager.swift
// --- UPDATED: Removed lines causing permissions errors ---

import Combine
import Foundation
import FirebaseFirestore

enum RequestError: Error, LocalizedError {
    case alreadyPending
    case alreadyApproved
    case blocked
    
    var errorDescription: String? {
        switch self {
        case .alreadyPending:
            return "A request is already pending with this instructor."
        case .alreadyApproved:
            return "You are already an approved student of this instructor."
        case .blocked:
            return "You are not allowed to send a request to this instructor."
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
                if status == RequestStatus.blocked.rawValue {
                    print("Student is blocked by this instructor.")
                    throw RequestError.blocked
                }
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

    // Fetches PENDING requests
    func fetchRequests(for instructorID: String) async throws -> [StudentRequest] {
        let snapshot = try await requestsCollection
            .whereField("instructorID", isEqualTo: instructorID)
            .whereField("status", isEqualTo: RequestStatus.pending.rawValue)
            .order(by: "timestamp", descending: true)
            .getDocuments()
            
        return snapshot.documents.compactMap { try? $0.data(as: StudentRequest.self) }
    }
    
    // Fetches DENIED requests
    func fetchDeniedRequests(for instructorID: String) async throws -> [StudentRequest] {
        let snapshot = try await requestsCollection
            .whereField("instructorID", isEqualTo: instructorID)
            .whereField("status", isEqualTo: RequestStatus.denied.rawValue)
            .order(by: "timestamp", descending: true)
            .getDocuments()
            
        return snapshot.documents.compactMap { try? $0.data(as: StudentRequest.self) }
    }
    
    // Fetches BLOCKED requests
    func fetchBlockedRequests(for instructorID: String) async throws -> [StudentRequest] {
        let snapshot = try await requestsCollection
            .whereField("instructorID", isEqualTo: instructorID)
            .whereField("status", isEqualTo: RequestStatus.blocked.rawValue)
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
        
        // 1. Update the request to "approved"
        let requestRef = requestsCollection.document(requestID)
        batch.updateData(["status": RequestStatus.approved.rawValue], forDocument: requestRef)
        
        // 2. Add student ID to instructor's "studentIDs" array
        let instructorRef = usersCollection.document(request.instructorID)
        batch.updateData(["studentIDs": FieldValue.arrayUnion([request.studentID])], forDocument: instructorRef)
        
        // 3. Create the new conversation
        let conversationRef = conversationsCollection.document()
        try batch.setData(from: newConversation, forDocument: conversationRef)
        
        // 4. Commit the batch
        try await batch.commit()
    }
    
    func denyRequest(_ request: StudentRequest) async throws {
        guard let requestID = request.id else { throw URLError(.badServerResponse) }
        try await requestsCollection.document(requestID).updateData(["status": RequestStatus.denied.rawValue])
    }
    
    // "Remove" - sets status to denied
    func removeStudent(studentID: String, instructorID: String) async throws {
        let batch = db.batch()
        
        let instructorRef = usersCollection.document(instructorID)
        batch.updateData(["studentIDs": FieldValue.arrayRemove([studentID])], forDocument: instructorRef)
        
        // --- THIS LINE WAS THE ERROR AND IS NOW REMOVED ---
        // let studentRef = usersCollection.document(studentID)
        // batch.updateData(["instructorIDs": FieldValue.arrayRemove([instructorID])], forDocument: studentRef)
        
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
    
    // "Block" - sets status to blocked
    func blockStudent(studentID: String, instructorID: String) async throws {
        let batch = db.batch()
        
        // 1. Remove from instructor's list
        let instructorRef = usersCollection.document(instructorID)
        batch.updateData(["studentIDs": FieldValue.arrayRemove([studentID])], forDocument: instructorRef)
        
        // --- THIS LINE WAS THE ERROR AND IS NOW REMOVED ---
        // let studentRef = usersCollection.document(studentID)
        // batch.updateData(["instructorIDs": FieldValue.arrayRemove([instructorID])], forDocument: studentRef)
        
        // 3. Find *any* request (approved, pending, or denied) and update it to 'blocked'
        let requestQuery = try await requestsCollection
            .whereField("studentID", isEqualTo: studentID)
            .whereField("instructorID", isEqualTo: instructorID)
            .getDocuments()
        
        if requestQuery.documents.isEmpty {
            // No request exists, create a new one just to mark as blocked
            print("No existing request, creating new 'blocked' record.")
            
            let studentDoc = try? await usersCollection.document(studentID).getDocument()
            let studentName = (try? studentDoc?.data(as: AppUser.self))?.name ?? "Blocked User"
            let studentPhoto = (try? studentDoc?.data(as: AppUser.self))?.photoURL
            
            let newBlockedRequest = StudentRequest(
                studentID: studentID,
                studentName: studentName,
                studentPhotoURL: studentPhoto,
                instructorID: instructorID,
                status: .blocked,
                timestamp: Date()
            )
            
            let newReqRef = requestsCollection.document()
            try batch.setData(from: newBlockedRequest, forDocument: newReqRef)
            
        } else {
            // Request(s) exist, update them all to 'blocked'
            print("Found \(requestQuery.documents.count) existing requests. Setting all to 'blocked'.")
            for doc in requestQuery.documents {
                batch.updateData(["status": RequestStatus.blocked.rawValue], forDocument: doc.reference)
            }
        }
        
        try await batch.commit()
    }
    
    // "Remove Instructor" (Called by Student)
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
