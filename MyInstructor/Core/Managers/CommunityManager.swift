// File: Core/Managers/CommunityManager.swift
// --- UPDATED: unblockInstructor and removeInstructor to fix permission/timestamp bugs ---
// --- UPDATED: Added update/delete functions for offline students ---

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
    
    // --- *** ADD THIS NEW COLLECTION REFERENCE *** ---
    private var offlineStudentsCollection: CollectionReference {
        db.collection("offline_students")
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
    
    // MARK: - --- OFFLINE STUDENT FUNCTIONS ---
    
    /// Creates a new "offline" student record, owned by the instructor.
    func addOfflineStudent(instructorID: String, name: String, phone: String?, email: String?, address: String?) async throws {
        let newOfflineStudent = OfflineStudent(
            instructorID: instructorID,
            name: name,
            phone: phone,
            email: email,
            address: address
        )
        
        // Add the new document to the 'offline_students' collection
        try offlineStudentsCollection.addDocument(from: newOfflineStudent)
        print("Offline student '\(name)' added successfully.")
    }
    
    // --- *** ADD THIS NEW FUNCTION *** ---
    /// Updates an existing offline student document.
    func updateOfflineStudent(_ student: OfflineStudent) async throws {
        guard let studentID = student.id else {
            throw NSError(domain: "CommunityManager", code: 0, userInfo: [NSLocalizedDescriptionKey: "Missing student ID for update."])
        }
        
        // Use updateData with a dictionary. This correctly handles
        // setting a value to nil (which removes it) vs. skipping it.
        try await offlineStudentsCollection.document(studentID).updateData([
            "name": student.name,
            "phone": student.phone ?? FieldValue.delete(),
            "email": student.email ?? FieldValue.delete(),
            "address": student.address ?? FieldValue.delete()
        ])
        print("Offline student '\(student.name)' updated successfully.")
    }

    // --- *** ADD THIS NEW FUNCTION *** ---
    /// Deletes an offline student document by their ID.
    func deleteOfflineStudent(studentID: String) async throws {
        try await offlineStudentsCollection.document(studentID).delete()
        print("Offline student deleted successfully.")
    }
    
    // MARK: - --- STUDENT REQUEST FUNCTIONS ---
    
    func sendRequest(from student: AppUser, to instructorID: String) async throws {
        guard let studentID = student.id else { throw URLError(.badServerResponse) }
        
        let existingRequests = try await self.fetchSentRequests(for: studentID)
        
        if let request = existingRequests.first(where: { $0.instructorID == instructorID }) {
            
            if request.status == .blocked {
                if request.blockedBy == "instructor" {
                    print("Student is blocked by this instructor.")
                    throw RequestError.blocked
                } else {
                    print("Found a student-blocked request. Deleting it to re-apply...")
                    try await requestsCollection.document(request.id!).delete()
                }
            }
            else if request.status == .pending {
                print("Request already pending.")
                throw RequestError.alreadyPending
            } else if request.status == .approved {
                print("Student is already approved by this instructor.")
                throw RequestError.alreadyApproved
            } else if request.status == .denied {
                print("Found a denied request. Deleting it to re-apply...")
                try await requestsCollection.document(request.id!).delete()
                print("Old request deleted.")
            }
        }
        
        print("Creating new request...")
        let newRequest = StudentRequest(
            studentID: studentID,
            studentName: student.name ?? "New Student",
            studentPhotoURL: student.photoURL,
            instructorID: instructorID,
            status: .pending,
            timestamp: Date(),
            blockedBy: nil
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
            .whereField("blockedBy", isEqualTo: "instructor") // Only fetch if instructor blocked
            .order(by: "timestamp", descending: true)
            .getDocuments()
            
        return snapshot.documents.compactMap { try? $0.data(as: StudentRequest.self) }
    }
    
    func approveRequest(_ request: StudentRequest) async throws {
        guard let requestID = request.id else { throw URLError(.badServerResponse) }
        
        let query = conversationsCollection
            .whereField("participantIDs", arrayContains: request.instructorID)
        
        let snapshot = try await query.getDocuments()
        var conversationExists = false
        
        for doc in snapshot.documents {
            let participantIDs = doc.data()["participantIDs"] as? [String] ?? []
            if participantIDs.contains(request.studentID) {
                conversationExists = true
                print("CommunityManager: Found existing conversation. Will not create a new one.")
                break
            }
        }
        
        let batch = db.batch()
        
        let requestRef = requestsCollection.document(requestID)
        batch.updateData([
            "status": RequestStatus.approved.rawValue,
            "blockedBy": FieldValue.delete()
        ], forDocument: requestRef)
        
        let instructorRef = usersCollection.document(request.instructorID)
        batch.updateData(["studentIDs": FieldValue.arrayUnion([request.studentID])], forDocument: instructorRef)
        
        if !conversationExists {
            print("CommunityManager: No existing chat. Creating a new one.")
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
            
            let conversationRef = conversationsCollection.document()
            try batch.setData(from: newConversation, forDocument: conversationRef)
        }
        
        try await batch.commit()
    }
    
    func denyRequest(_ request: StudentRequest) async throws {
        guard let requestID = request.id else { throw URLError(.badServerResponse) }
        try await requestsCollection.document(requestID).updateData([
            "status": RequestStatus.denied.rawValue,
            "blockedBy": FieldValue.delete()
        ])
    }
    
    // "Remove" - sets status to denied
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
            batch.updateData([
                "status": RequestStatus.denied.rawValue,
                "blockedBy": FieldValue.delete()
            ], forDocument: doc.reference)
        }
        
        try await batch.commit()
    }
    
    // "Block" - sets status to blocked (BY INSTRUCTOR)
    func blockStudent(studentID: String, instructorID: String) async throws {
        let batch = db.batch()
        
        let instructorRef = usersCollection.document(instructorID)
        batch.updateData(["studentIDs": FieldValue.arrayRemove([studentID])], forDocument: instructorRef)
        
        let requestQuery = try await requestsCollection
            .whereField("studentID", isEqualTo: studentID)
            .whereField("instructorID", isEqualTo: instructorID)
            .getDocuments()
        
        if requestQuery.documents.isEmpty {
            let studentDoc = try? await usersCollection.document(studentID).getDocument()
            let studentName = (try? studentDoc?.data(as: AppUser.self))?.name ?? "Blocked User"
            let studentPhoto = (try? studentDoc?.data(as: AppUser.self))?.photoURL
            
            let newBlockedRequest = StudentRequest(
                studentID: studentID,
                studentName: studentName,
                studentPhotoURL: studentPhoto,
                instructorID: instructorID,
                status: .blocked,
                timestamp: Date(),
                blockedBy: "instructor"
            )
            let newReqRef = requestsCollection.document()
            try batch.setData(from: newBlockedRequest, forDocument: newReqRef)
        } else {
            for doc in requestQuery.documents {
                batch.updateData([
                    "status": RequestStatus.blocked.rawValue,
                    "blockedBy": "instructor"
                ], forDocument: doc.reference)
            }
        }
        
        try await batch.commit()
    }
    
    // "Unblock" - sets status to denied (BY INSTRUCTOR)
    func unblockStudent(studentID: String, instructorID: String) async throws {
        let requestQuery = try await requestsCollection
            .whereField("studentID", isEqualTo: studentID)
            .whereField("instructorID", isEqualTo: instructorID)
            .whereField("status", isEqualTo: RequestStatus.blocked.rawValue)
            .whereField("blockedBy", isEqualTo: "instructor")
            .getDocuments()
            
        guard let doc = requestQuery.documents.first else {
            print("No 'instructor-blocked' request found to unblock.")
            return
        }
        
        try await doc.reference.updateData([
            "status": RequestStatus.denied.rawValue,
            "blockedBy": FieldValue.delete()
        ])
    }
    
    // Block (BY STUDENT)
    func blockInstructor(instructorID: String, student: AppUser) async throws {
        guard let studentID = student.id else { throw URLError(.badServerResponse) }
        let batch = db.batch()

        let studentRef = usersCollection.document(studentID)
        batch.updateData(["instructorIDs": FieldValue.arrayRemove([instructorID])], forDocument: studentRef)
        
        let requestQuery = try await requestsCollection
            .whereField("studentID", isEqualTo: studentID)
            .whereField("instructorID", isEqualTo: instructorID)
            .getDocuments()

        if !requestQuery.documents.isEmpty {
            for doc in requestQuery.documents {
                let request = try? doc.data(as: StudentRequest.self)
                if request?.status == .pending || request?.status == .denied || request?.blockedBy == "student" {
                    batch.deleteDocument(doc.reference)
                }
            }
        }

        let newBlockedRequest = StudentRequest(
            studentID: studentID,
            studentName: student.name ?? "Student",
            studentPhotoURL: student.photoURL,
            instructorID: instructorID,
            status: .blocked,
            timestamp: Date(),
            blockedBy: "student"
        )
        let newReqRef = requestsCollection.document()
        try batch.setData(from: newBlockedRequest, forDocument: newReqRef)
        
        try await batch.commit()
    }
    
    
    // --- *** THIS IS THE UPDATED FUNCTION *** ---
    // Unblock (BY STUDENT)
    func unblockInstructor(instructorID: String, studentID: String) async throws {
        let requestQuery = try await requestsCollection
            .whereField("studentID", isEqualTo: studentID)
            .whereField("instructorID", isEqualTo: instructorID)
            .whereField("status", isEqualTo: RequestStatus.blocked.rawValue)
            .whereField("blockedBy", isEqualTo: "student")
            .getDocuments()
            
        guard let doc = requestQuery.documents.first else {
            print("No 'student-blocked' request found to unblock.")
            return
        }
        
        // Update status to 'denied' AND update the timestamp
        // This makes it the "newest" request.
        try await doc.reference.updateData([
            "status": RequestStatus.denied.rawValue,
            "blockedBy": FieldValue.delete(),
            "timestamp": FieldValue.serverTimestamp() // <-- THIS IS THE FIX
        ])
    }
    
    
    // "Remove Instructor" (Called by Student)
    func removeInstructor(instructorID: String, studentID: String) async throws {
        let batch = db.batch()
        
        // 1. Remove instructor from student's list (Allowed)
        let studentRef = usersCollection.document(studentID)
        batch.updateData(["instructorIDs": FieldValue.arrayRemove([instructorID])], forDocument: studentRef)
        
        // 2. Find *only* pending/denied requests to delete (Allowed)
        let requestQuery = try await requestsCollection
            .whereField("studentID", isEqualTo: studentID)
            .whereField("instructorID", isEqualTo: instructorID)
            .getDocuments()
        
        var approvedDocRef: DocumentReference? = nil

        for doc in requestQuery.documents {
            let request = try? doc.data(as: StudentRequest.self)
            if request?.status == .approved {
                approvedDocRef = doc.reference // Save ref to approved doc
            } else {
                batch.deleteDocument(doc.reference) // Delete all others
            }
        }
        
        // 3. Create a new "denied" request
        // We create a new doc instead of updating the 'approved' one
        // to avoid permission errors.
        if let approvedRequestDoc = approvedDocRef {
             // Create a new denied request
             let studentDoc = try await usersCollection.document(studentID).getDocument()
             let student = try studentDoc.data(as: AppUser.self)
             
             let newDeniedRequest = StudentRequest(
                 studentID: studentID,
                 studentName: student.name ?? "Student",
                 studentPhotoURL: student.photoURL,
                 instructorID: instructorID,
                 status: .denied,
                 timestamp: Date(), // Set new timestamp
                 blockedBy: nil
             )
             let newReqRef = requestsCollection.document()
             try batch.setData(from: newDeniedRequest, forDocument: newReqRef)
             
             // We can't delete the approved doc, so we leave it.
             // The new "denied" doc will be newer and take precedence.
        }

        try await batch.commit()
    }
    
    func fetchSentRequests(for studentID: String) async throws -> [StudentRequest] {
        let snapshot = try await requestsCollection
            .whereField("studentID", isEqualTo: studentID)
            .order(by: "timestamp", descending: true)
            .getDocuments()
            
        let requests = snapshot.documents.compactMap { try? $0.data(as: StudentRequest.self) }
        
        // De-duplicate in code: Only keep the *newest* request for each instructor
        var uniqueRequests: [StudentRequest] = []
        var seenInstructorIDs = Set<String>()

        for request in requests {
            if !seenInstructorIDs.contains(request.instructorID) {
                uniqueRequests.append(request)
                seenInstructorIDs.insert(request.instructorID)
            }
        }
        
        return uniqueRequests
    }
    
    func cancelRequest(requestID: String) async throws {
        try await requestsCollection.document(requestID).delete()
    }
}
