// File: arafatrahman/myinstructor/MyInstructor-main/MyInstructor/Core/Managers/CommunityManager.swift
// --- UPDATED: Fixed 'deleteStudentNote' to reliably remove notes by ID ---

import Combine
import Foundation
import FirebaseFirestore
import FirebaseStorage

class CommunityManager: ObservableObject {
    private let db = Firestore.firestore()
    
    // Collection References
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
    private var offlineStudentsCollection: CollectionReference {
        db.collection("offline_students")
    }
    
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

    // MARK: - Community Posts
    
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
    
    func deletePost(postID: String) async throws {
        let postDoc = try await postsCollection.document(postID).getDocument()
        let post = try? postDoc.data(as: Post.self)
        
        try await postsCollection.document(postID).delete()
        
        if let mediaURLs = post?.mediaURLs {
            await withTaskGroup(of: Void.self) { group in
                for urlString in mediaURLs {
                    group.addTask {
                        try? await StorageManager.shared.deleteMedia(from: urlString)
                    }
                }
            }
        }
    }

    func updatePostDetails(
        postID: String,
        content: String?,
        location: String?,
        visibility: PostVisibility,
        newMediaURLs: [String]?
    ) async throws {
        let postRef = postsCollection.document(postID)
        let oldPostDoc = try await postRef.getDocument()
        let oldPost = try? oldPostDoc.data(as: Post.self)
        
        let oldURLs = Set(oldPost?.mediaURLs ?? [])
        let newURLs = Set(newMediaURLs ?? [])
        let removedURLs = oldURLs.subtracting(newURLs)
        
        if !removedURLs.isEmpty {
            await withTaskGroup(of: Void.self) { group in
                for urlString in removedURLs {
                    group.addTask {
                        try? await StorageManager.shared.deleteMedia(from: urlString)
                    }
                }
            }
        }

        try await postRef.updateData([
            "content": content ?? FieldValue.delete(),
            "location": location ?? FieldValue.delete(),
            "visibility": visibility.rawValue,
            "isEdited": true,
            "mediaURLs": newMediaURLs ?? FieldValue.delete()
        ])
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
    
    // MARK: - --- POST INTERACTIONS ---
    
    func addReaction(postID: String, reactionType: String) async throws {
        guard ["thumbsup", "fire", "heart"].contains(reactionType) else {
            throw NSError(domain: "CommunityManager", code: 0, userInfo: [NSLocalizedDescriptionKey: "Invalid reaction type."])
        }
        try await postsCollection.document(postID).updateData([
            "reactionsCount.\(reactionType)": FieldValue.increment(1.0)
        ])
    }
    
    func fetchComments(for postID: String) async throws -> [Comment] {
        let snapshot = try await postsCollection.document(postID)
            .collection("comments")
            .order(by: "timestamp", descending: false)
            .getDocuments()
        return snapshot.documents.compactMap { try? $0.data(as: Comment.self) }
    }
    
    func addComment(postID: String, authorID: String, authorName: String, authorRole: UserRole, authorPhotoURL: String?, content: String, parentCommentID: String?) async throws {
        let postRef = postsCollection.document(postID)
        let commentCollection = postRef.collection("comments")
        
        let newComment = Comment(
            postID: postID,
            authorID: authorID,
            authorName: authorName,
            authorPhotoURL: authorPhotoURL,
            authorRole: authorRole,
            timestamp: Date(),
            content: content,
            parentCommentID: parentCommentID
        )
        
        let batch = db.batch()
        let newCommentRef = commentCollection.document()
        try batch.setData(from: newComment, forDocument: newCommentRef)
        
        batch.updateData(["commentsCount": FieldValue.increment(1.0)], forDocument: postRef)
        
        if let parentID = parentCommentID {
            let parentCommentRef = commentCollection.document(parentID)
            batch.updateData(["repliesCount": FieldValue.increment(1.0)], forDocument: parentCommentRef)
        }
        
        try await batch.commit()
    }
    
    func deleteComment(postID: String, commentID: String, parentCommentID: String?) async throws {
        let postRef = postsCollection.document(postID)
        let commentRef = postRef.collection("comments").document(commentID)
        
        let batch = db.batch()
        batch.deleteDocument(commentRef)
        batch.updateData(["commentsCount": FieldValue.increment(-1.0)], forDocument: postRef)
        
        if let parentID = parentCommentID {
            let parentRef = postRef.collection("comments").document(parentID)
            batch.updateData(["repliesCount": FieldValue.increment(-1.0)], forDocument: parentRef)
        }
        try await batch.commit()
    }
    
    func updateComment(postID: String, commentID: String, newContent: String) async throws {
        let commentRef = postsCollection.document(postID).collection("comments").document(commentID)
        try await commentRef.updateData([
            "content": newContent,
            "isEdited": true
        ])
    }
    
    // MARK: - --- STUDENT REQUEST FUNCTIONS ---
    
    func sendRequest(from student: AppUser, to instructorID: String) async throws {
        guard let studentID = student.id else { throw URLError(.badServerResponse) }
        
        let existingRequests = try await self.fetchSentRequests(for: studentID)
        
        if let request = existingRequests.first(where: { $0.instructorID == instructorID }) {
            if request.status == .blocked {
                if request.blockedBy == "instructor" { throw RequestError.blocked }
                else { try await requestsCollection.document(request.id!).delete() }
            }
            else if request.status == .pending { throw RequestError.alreadyPending }
            else if request.status == .approved { throw RequestError.alreadyApproved }
            else if request.status == .denied { try await requestsCollection.document(request.id!).delete() }
        }
        
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
    }

    func fetchRequests(for instructorID: String) async throws -> [StudentRequest] {
        let snapshot = try await requestsCollection
            .whereField("instructorID", isEqualTo: instructorID)
            .whereField("status", isEqualTo: RequestStatus.pending.rawValue)
            .order(by: "timestamp", descending: true)
            .getDocuments()
        return snapshot.documents.compactMap { try? $0.data(as: StudentRequest.self) }
    }
    
    func fetchDeniedRequests(for instructorID: String) async throws -> [StudentRequest] {
        let snapshot = try await requestsCollection
            .whereField("instructorID", isEqualTo: instructorID)
            .whereField("status", isEqualTo: RequestStatus.denied.rawValue)
            .order(by: "timestamp", descending: true)
            .getDocuments()
        return snapshot.documents.compactMap { try? $0.data(as: StudentRequest.self) }
    }

    func fetchBlockedRequests(for instructorID: String) async throws -> [StudentRequest] {
        let snapshot = try await requestsCollection
            .whereField("instructorID", isEqualTo: instructorID)
            .whereField("status", isEqualTo: RequestStatus.blocked.rawValue)
            .whereField("blockedBy", isEqualTo: "instructor")
            .order(by: "timestamp", descending: true)
            .getDocuments()
        return snapshot.documents.compactMap { try? $0.data(as: StudentRequest.self) }
    }
    
    func approveRequest(_ request: StudentRequest) async throws {
        guard let requestID = request.id else { throw URLError(.badServerResponse) }
        
        let query = conversationsCollection.whereField("participantIDs", arrayContains: request.instructorID)
        let snapshot = try await query.getDocuments()
        var conversationExists = false
        
        for doc in snapshot.documents {
            let participantIDs = doc.data()["participantIDs"] as? [String] ?? []
            if participantIDs.contains(request.studentID) {
                conversationExists = true
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
    
    func unblockStudent(studentID: String, instructorID: String) async throws {
        let requestQuery = try await requestsCollection
            .whereField("studentID", isEqualTo: studentID)
            .whereField("instructorID", isEqualTo: instructorID)
            .whereField("status", isEqualTo: RequestStatus.blocked.rawValue)
            .whereField("blockedBy", isEqualTo: "instructor")
            .getDocuments()
            
        guard let doc = requestQuery.documents.first else { return }
        try await doc.reference.updateData([
            "status": RequestStatus.denied.rawValue,
            "blockedBy": FieldValue.delete()
        ])
    }
    
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
    
    func unblockInstructor(instructorID: String, studentID: String) async throws {
        let requestQuery = try await requestsCollection
            .whereField("studentID", isEqualTo: studentID)
            .whereField("instructorID", isEqualTo: instructorID)
            .whereField("status", isEqualTo: RequestStatus.blocked.rawValue)
            .whereField("blockedBy", isEqualTo: "student")
            .getDocuments()
            
        guard let doc = requestQuery.documents.first else { return }
        try await doc.reference.updateData([
            "status": RequestStatus.denied.rawValue,
            "blockedBy": FieldValue.delete(),
            "timestamp": FieldValue.serverTimestamp()
        ])
    }
    
    func removeInstructor(instructorID: String, studentID: String) async throws {
        let batch = db.batch()
        let studentRef = usersCollection.document(studentID)
        batch.updateData(["instructorIDs": FieldValue.arrayRemove([instructorID])], forDocument: studentRef)
        
        let requestQuery = try await requestsCollection
            .whereField("studentID", isEqualTo: studentID)
            .whereField("instructorID", isEqualTo: instructorID)
            .getDocuments()
        
        var approvedDocRef: DocumentReference? = nil

        for doc in requestQuery.documents {
            let request = try? doc.data(as: StudentRequest.self)
            if request?.status == .approved {
                approvedDocRef = doc.reference
            } else {
                batch.deleteDocument(doc.reference)
            }
        }
        
        if let approvedRequestDoc = approvedDocRef {
             let studentDoc = try await usersCollection.document(studentID).getDocument()
             let student = try studentDoc.data(as: AppUser.self)
             
             let newDeniedRequest = StudentRequest(
                 studentID: studentID,
                 studentName: student.name ?? "Student",
                 studentPhotoURL: student.photoURL,
                 instructorID: instructorID,
                 status: .denied,
                 timestamp: Date(),
                 blockedBy: nil
             )
             let newReqRef = requestsCollection.document()
             try batch.setData(from: newDeniedRequest, forDocument: newReqRef)
             
             batch.deleteDocument(approvedRequestDoc)
        }
        try await batch.commit()
    }
    
    func fetchSentRequests(for studentID: String) async throws -> [StudentRequest] {
        let snapshot = try await requestsCollection
            .whereField("studentID", isEqualTo: studentID)
            .order(by: "timestamp", descending: true)
            .getDocuments()
            
        let requests = snapshot.documents.compactMap { try? $0.data(as: StudentRequest.self) }
        
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
    
    // MARK: - --- OFFLINE STUDENT MANAGEMENT ---
    
    func addOfflineStudent(instructorID: String, name: String, phone: String?, email: String?, address: String?) async throws {
        let newOfflineStudent = OfflineStudent(
            instructorID: instructorID,
            name: name,
            phone: phone,
            email: email,
            address: address
        )
        try offlineStudentsCollection.addDocument(from: newOfflineStudent)
        print("Offline student '\(name)' added successfully.")
    }
    
    func updateOfflineStudent(_ student: OfflineStudent) async throws {
        guard let studentID = student.id else {
            throw NSError(domain: "CommunityManager", code: 0, userInfo: [NSLocalizedDescriptionKey: "Missing student ID for update."])
        }
        try await offlineStudentsCollection.document(studentID).updateData([
            "name": student.name,
            "phone": student.phone ?? FieldValue.delete(),
            "email": student.email ?? FieldValue.delete(),
            "address": student.address ?? FieldValue.delete()
        ])
        print("Offline student '\(student.name)' updated successfully.")
    }

    func deleteOfflineStudent(studentID: String) async throws {
        try await offlineStudentsCollection.document(studentID).delete()
        print("Offline student deleted successfully.")
    }

    // MARK: - --- PROGRESS & NOTES MANAGEMENT ---

    /// Updates the progress for a student. Handles both Online and Offline types.
    func updateStudentProgress(instructorID: String, studentID: String, newProgress: Double, isOffline: Bool) async throws {
        if isOffline {
            // Update the OfflineStudent document directly
            try await offlineStudentsCollection.document(studentID).updateData([
                "progress": newProgress
            ])
        } else {
            // Update the Instructor's private record for this Online Student
            let recordRef = usersCollection.document(instructorID).collection("student_records").document(studentID)
            try await recordRef.setData(["progress": newProgress], merge: true)
        }
        print("Progress updated for student \(studentID)")
    }

    /// Adds a note for a student. Handles both Online and Offline types.
    func addStudentNote(instructorID: String, studentID: String, noteContent: String, isOffline: Bool) async throws {
        let newNote = StudentNote(content: noteContent, timestamp: Date())
        
        // Convert note to dictionary for Firestore array
        guard let noteData = try? Firestore.Encoder().encode(newNote) else { return }

        if isOffline {
            try await offlineStudentsCollection.document(studentID).updateData([
                "notes": FieldValue.arrayUnion([noteData])
            ])
        } else {
            let recordRef = usersCollection.document(instructorID).collection("student_records").document(studentID)
            try await recordRef.setData(["notes": FieldValue.arrayUnion([noteData])], merge: true)
        }
        print("Note added for student \(studentID)")
    }
    
    // --- *** THIS IS THE FIXED FUNCTION *** ---
    /// Deletes a specific note by its ID (Robust way).
    func deleteStudentNote(instructorID: String, studentID: String, note: StudentNote, isOffline: Bool) async throws {
        // Use the "Read-Modify-Write" approach to ensure we remove by ID, ignoring minor timestamp differences
        
        var currentNotes: [StudentNote] = []
        var docRef: DocumentReference
        
        // 1. Get the correct reference and fetch current data
        if isOffline {
            docRef = offlineStudentsCollection.document(studentID)
            let doc = try await docRef.getDocument()
            let offlineStudent = try? doc.data(as: OfflineStudent.self)
            currentNotes = offlineStudent?.notes ?? []
        } else {
            docRef = usersCollection.document(instructorID).collection("student_records").document(studentID)
            let doc = try await docRef.getDocument()
            let record = try? doc.data(as: StudentRecord.self)
            currentNotes = record?.notes ?? []
        }
        
        // 2. Filter out the note to delete based on ID
        let updatedNotes = currentNotes.filter { $0.id != note.id }
        
        // 3. Save the updated array back to Firestore
        // We map the note objects to dictionaries
        let notesData = try updatedNotes.map { try Firestore.Encoder().encode($0) }
        
        try await docRef.updateData([
            "notes": notesData
        ])
        
        print("Note deleted for student \(studentID) using filter method.")
    }
    // --- *** END OF FIXED FUNCTION *** ---
    
    /// Updates a specific note (edit).
    func updateStudentNote(instructorID: String, studentID: String, oldNote: StudentNote, newContent: String, isOffline: Bool) async throws {
        // 1. Fetch current notes list
        var currentNotes: [StudentNote] = []
        if isOffline {
            let doc = try await offlineStudentsCollection.document(studentID).getDocument()
            let offlineStudent = try? doc.data(as: OfflineStudent.self)
            currentNotes = offlineStudent?.notes ?? []
        } else {
            let doc = try await usersCollection.document(instructorID).collection("student_records").document(studentID).getDocument()
            let record = try? doc.data(as: StudentRecord.self)
            currentNotes = record?.notes ?? []
        }
        
        // 2. Find and update the note
        if let index = currentNotes.firstIndex(where: { $0.id == oldNote.id }) {
            currentNotes[index] = StudentNote(id: oldNote.id, content: newContent, timestamp: oldNote.timestamp)
            
            // 3. Write the entire array back
            guard let notesData = try? currentNotes.map({ try Firestore.Encoder().encode($0) }) else { return }
            
            if isOffline {
                try await offlineStudentsCollection.document(studentID).updateData(["notes": notesData])
            } else {
                let recordRef = usersCollection.document(instructorID).collection("student_records").document(studentID)
                try await recordRef.updateData(["notes": notesData])
            }
            print("Note updated for student \(studentID)")
        }
    }
    
    /// Fetches the instructor-specific data (Progress & Notes) for a student
    func fetchInstructorStudentData(instructorID: String, studentID: String, isOffline: Bool) async throws -> StudentRecord? {
        if isOffline {
            let doc = try await offlineStudentsCollection.document(studentID).getDocument()
            guard let offlineStudent = try? doc.data(as: OfflineStudent.self) else { return nil }
            return StudentRecord(id: studentID, progress: offlineStudent.progress, notes: offlineStudent.notes)
        } else {
            let doc = try await usersCollection.document(instructorID).collection("student_records").document(studentID).getDocument()
            if doc.exists {
                return try? doc.data(as: StudentRecord.self)
            } else {
                return nil
            }
        }
    }
}
