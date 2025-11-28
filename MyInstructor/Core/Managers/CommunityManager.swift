import Combine
import Foundation
import FirebaseFirestore
import FirebaseStorage

class CommunityManager: ObservableObject {
    private let db = Firestore.firestore()
    
    private var postsCollection: CollectionReference { db.collection("community_posts") }
    private var usersCollection: CollectionReference { db.collection("users") }
    private var requestsCollection: CollectionReference { db.collection("student_requests") }
    private var conversationsCollection: CollectionReference { db.collection("conversations") }
    private var offlineStudentsCollection: CollectionReference { db.collection("offline_students") }
    
    enum RequestError: Error, LocalizedError {
        case alreadyPending, alreadyApproved, blocked
        var errorDescription: String? {
            switch self {
            case .alreadyPending: return "A request is already pending."
            case .alreadyApproved: return "You are already an approved student."
            case .blocked: return "You are blocked."
            }
        }
    }

    // MARK: - Community Posts
    
    func fetchPosts(filter: String) async throws -> [Post] {
        // Basic filtering logic can be expanded. Currently fetching all for simplicity.
        let snapshot = try await postsCollection.order(by: "timestamp", descending: true).limit(to: 20).getDocuments()
        return snapshot.documents.compactMap { try? $0.data(as: Post.self) }
    }
    
    func createPost(post: Post) async throws {
        try postsCollection.addDocument(from: post)
    }
    
    func deletePost(postID: String) async throws {
        try await postsCollection.document(postID).delete()
    }

    func updatePostDetails(postID: String, content: String?, location: String?, visibility: PostVisibility, newMediaURLs: [String]?) async throws {
        var data: [String: Any] = [
            "visibility": visibility.rawValue,
            "isEdited": true
        ]
        if let content = content { data["content"] = content }
        if let location = location { data["location"] = location }
        if let urls = newMediaURLs { data["mediaURLs"] = urls }
        
        try await postsCollection.document(postID).updateData(data)
    }
    
    // MARK: - Directory & Reactions

    func fetchInstructorDirectory(filters: [String: Any]) async throws -> [Student] {
        let snapshot = try await usersCollection.whereField("role", isEqualTo: UserRole.instructor.rawValue).limit(to: 20).getDocuments()
        return snapshot.documents.compactMap { try? $0.data(as: AppUser.self) }.map { appUser in
            Student(id: appUser.id, userID: appUser.id ?? "", name: appUser.name ?? "Instructor", photoURL: appUser.photoURL, email: appUser.email, drivingSchool: appUser.drivingSchool, phone: appUser.phone, address: appUser.address)
        }
    }
    
    func addReaction(postID: String, reactionType: String) async throws {
        try await postsCollection.document(postID).updateData(["reactionsCount.\(reactionType)": FieldValue.increment(1.0)])
    }
    
    // MARK: - Comments
    
    func fetchComments(for postID: String) async throws -> [Comment] {
        let snapshot = try await postsCollection.document(postID).collection("comments").order(by: "timestamp", descending: false).getDocuments()
        return snapshot.documents.compactMap { try? $0.data(as: Comment.self) }
    }
    
    func addComment(postID: String, authorID: String, authorName: String, authorRole: UserRole, authorPhotoURL: String?, content: String, parentCommentID: String?) async throws {
        let newComment = Comment(postID: postID, authorID: authorID, authorName: authorName, authorPhotoURL: authorPhotoURL, authorRole: authorRole, timestamp: Date(), content: content, parentCommentID: parentCommentID)
        try postsCollection.document(postID).collection("comments").addDocument(from: newComment)
        try await postsCollection.document(postID).updateData(["commentsCount": FieldValue.increment(1.0)])
    }
    
    func deleteComment(postID: String, commentID: String, parentCommentID: String?) async throws {
        try await postsCollection.document(postID).collection("comments").document(commentID).delete()
        try await postsCollection.document(postID).updateData(["commentsCount": FieldValue.increment(-1.0)])
    }
    
    func updateComment(postID: String, commentID: String, newContent: String) async throws {
        try await postsCollection.document(postID).collection("comments").document(commentID).updateData(["content": newContent, "isEdited": true])
    }
    
    // MARK: - Student Requests
    
    func sendRequest(from student: AppUser, to instructorID: String) async throws {
        // Check for existing
        let query = requestsCollection
            .whereField("studentID", isEqualTo: student.id!)
            .whereField("instructorID", isEqualTo: instructorID)
        
        let snapshot = try await query.getDocuments()
        if let existing = snapshot.documents.first {
            let status = try? existing.data(as: StudentRequest.self).status
            if status == .pending { throw RequestError.alreadyPending }
            if status == .approved { throw RequestError.alreadyApproved }
            if status == .blocked { throw RequestError.blocked }
        }

        let newRequest = StudentRequest(studentID: student.id!, studentName: student.name ?? "", studentPhotoURL: student.photoURL, instructorID: instructorID, status: .pending, timestamp: Date(), blockedBy: nil)
        try requestsCollection.addDocument(from: newRequest)
    }

    func fetchRequests(for instructorID: String) async throws -> [StudentRequest] {
        let snapshot = try await requestsCollection.whereField("instructorID", isEqualTo: instructorID).whereField("status", isEqualTo: RequestStatus.pending.rawValue).getDocuments()
        return snapshot.documents.compactMap { try? $0.data(as: StudentRequest.self) }
    }
    
    func fetchDeniedRequests(for instructorID: String) async throws -> [StudentRequest] {
        let snapshot = try await requestsCollection.whereField("instructorID", isEqualTo: instructorID).whereField("status", isEqualTo: RequestStatus.denied.rawValue).getDocuments()
        return snapshot.documents.compactMap { try? $0.data(as: StudentRequest.self) }
    }
    
    func fetchBlockedRequests(for instructorID: String) async throws -> [StudentRequest] {
        let snapshot = try await requestsCollection.whereField("instructorID", isEqualTo: instructorID).whereField("status", isEqualTo: RequestStatus.blocked.rawValue).getDocuments()
        return snapshot.documents.compactMap { try? $0.data(as: StudentRequest.self) }
    }
    
    func approveRequest(_ request: StudentRequest) async throws {
        guard let id = request.id else { return }
        try await requestsCollection.document(id).updateData(["status": RequestStatus.approved.rawValue])
        try await usersCollection.document(request.instructorID).updateData(["studentIDs": FieldValue.arrayUnion([request.studentID])])
        // Also update student's instructor list
        try await usersCollection.document(request.studentID).updateData(["instructorIDs": FieldValue.arrayUnion([request.instructorID])])
    }
    
    func denyRequest(_ request: StudentRequest) async throws {
        guard let id = request.id else { return }
        try await requestsCollection.document(id).updateData(["status": RequestStatus.denied.rawValue])
    }
    
    func removeStudent(studentID: String, instructorID: String) async throws {
        // Remove from instructor's list
        try await usersCollection.document(instructorID).updateData(["studentIDs": FieldValue.arrayRemove([studentID])])
        // Remove from student's instructor list
        try await usersCollection.document(studentID).updateData(["instructorIDs": FieldValue.arrayRemove([instructorID])])
        
        // Remove the connection request
        let query = requestsCollection.whereField("studentID", isEqualTo: studentID).whereField("instructorID", isEqualTo: instructorID)
        let snapshot = try await query.getDocuments()
        for doc in snapshot.documents {
            try await doc.reference.delete()
        }
    }
    
    func blockStudent(studentID: String, instructorID: String) async throws {
        let query = requestsCollection.whereField("studentID", isEqualTo: studentID).whereField("instructorID", isEqualTo: instructorID)
        let snapshot = try await query.getDocuments()
        
        if let doc = snapshot.documents.first {
            try await doc.reference.updateData(["status": RequestStatus.blocked.rawValue, "blockedBy": "instructor"])
        } else {
            let newRequest = StudentRequest(studentID: studentID, studentName: "Blocked User", studentPhotoURL: nil, instructorID: instructorID, status: .blocked, timestamp: Date(), blockedBy: "instructor")
            try requestsCollection.addDocument(from: newRequest)
        }
        
        try await usersCollection.document(instructorID).updateData(["studentIDs": FieldValue.arrayRemove([studentID])])
        try await usersCollection.document(studentID).updateData(["instructorIDs": FieldValue.arrayRemove([instructorID])])
    }
    
    func unblockStudent(studentID: String, instructorID: String) async throws {
        let query = requestsCollection.whereField("studentID", isEqualTo: studentID).whereField("instructorID", isEqualTo: instructorID)
        let snapshot = try await query.getDocuments()
        for doc in snapshot.documents {
            try await doc.reference.delete()
        }
    }
    
    func blockInstructor(instructorID: String, student: AppUser) async throws {
        guard let studentID = student.id else { return }
        let query = requestsCollection.whereField("studentID", isEqualTo: studentID).whereField("instructorID", isEqualTo: instructorID)
        let snapshot = try await query.getDocuments()
        
        if let doc = snapshot.documents.first {
            try await doc.reference.updateData(["status": RequestStatus.blocked.rawValue, "blockedBy": "student"])
        } else {
             let newRequest = StudentRequest(studentID: studentID, studentName: student.name ?? "", studentPhotoURL: student.photoURL, instructorID: instructorID, status: .blocked, timestamp: Date(), blockedBy: "student")
             try requestsCollection.addDocument(from: newRequest)
        }
        
        try await usersCollection.document(instructorID).updateData(["studentIDs": FieldValue.arrayRemove([studentID])])
        try await usersCollection.document(studentID).updateData(["instructorIDs": FieldValue.arrayRemove([instructorID])])
    }
    
    func unblockInstructor(instructorID: String, studentID: String) async throws {
        let query = requestsCollection.whereField("studentID", isEqualTo: studentID).whereField("instructorID", isEqualTo: instructorID)
        let snapshot = try await query.getDocuments()
        for doc in snapshot.documents {
            try await doc.reference.delete()
        }
    }
    
    func removeInstructor(instructorID: String, studentID: String) async throws {
        try await removeStudent(studentID: studentID, instructorID: instructorID)
    }
    
    func fetchSentRequests(for studentID: String) async throws -> [StudentRequest] {
        let snapshot = try await requestsCollection.whereField("studentID", isEqualTo: studentID).getDocuments()
        return snapshot.documents.compactMap { try? $0.data(as: StudentRequest.self) }
    }
    
    func cancelRequest(requestID: String) async throws {
        try await requestsCollection.document(requestID).delete()
    }
    
    // MARK: - Offline Students
    
    func addOfflineStudent(instructorID: String, name: String, phone: String?, email: String?, address: String?) async throws {
        try offlineStudentsCollection.addDocument(from: OfflineStudent(instructorID: instructorID, name: name, phone: phone, email: email, address: address))
    }
    
    func updateOfflineStudent(_ student: OfflineStudent) async throws {
        guard let id = student.id else { return }
        try offlineStudentsCollection.document(id).setData(from: student)
    }

    func deleteOfflineStudent(studentID: String) async throws {
        try await offlineStudentsCollection.document(studentID).delete()
    }

    // MARK: - Student Progress & Notes
    
    func updateStudentProgress(instructorID: String, studentID: String, newProgress: Double, isOffline: Bool) async throws {
        if isOffline {
            try await offlineStudentsCollection.document(studentID).updateData(["progress": newProgress])
        } else {
            let recordRef = usersCollection.document(instructorID).collection("student_records").document(studentID)
            try await recordRef.setData(["progress": newProgress], merge: true)
            
            NotificationManager.shared.sendNotification(
                to: studentID,
                title: "Progress Updated",
                message: "Your mastery level has been updated to \(Int(newProgress * 100))%.",
                type: "progress"
            )
        }
    }

    func addStudentNote(instructorID: String, studentID: String, noteContent: String, isOffline: Bool) async throws {
        let newNote = StudentNote(content: noteContent, timestamp: Date())
        guard let noteData = try? Firestore.Encoder().encode(newNote) else { return }

        if isOffline {
            try await offlineStudentsCollection.document(studentID).updateData(["notes": FieldValue.arrayUnion([noteData])])
        } else {
            let recordRef = usersCollection.document(instructorID).collection("student_records").document(studentID)
            try await recordRef.setData(["notes": FieldValue.arrayUnion([noteData])], merge: true)
            
            NotificationManager.shared.sendNotification(
                to: studentID,
                title: "New Note from Instructor",
                message: "You received a new note: \"\(noteContent)\"",
                type: "note"
            )
        }
    }
    
    // --- UPDATED: Implemented Logic ---
    func deleteStudentNote(instructorID: String, studentID: String, note: StudentNote, isOffline: Bool) async throws {
        let ref: DocumentReference
        if isOffline {
            ref = offlineStudentsCollection.document(studentID)
        } else {
            ref = usersCollection.document(instructorID).collection("student_records").document(studentID)
        }
        
        let doc = try await ref.getDocument()
        if doc.exists {
            var notesToUpdate: [StudentNote] = []
            
            // Extract existing notes based on offline status
            if isOffline {
                if let student = try? doc.data(as: OfflineStudent.self), let notes = student.notes {
                    notesToUpdate = notes
                }
            } else {
                if let record = try? doc.data(as: StudentRecord.self), let notes = record.notes {
                    notesToUpdate = notes
                }
            }
            
            // Filter out the note to delete
            let filteredNotes = notesToUpdate.filter { $0.id != note.id }
            
            // Encode and save back
            let encodedNotes = try filteredNotes.map { try Firestore.Encoder().encode($0) }
            try await ref.updateData(["notes": encodedNotes])
        }
    }
    
    // --- UPDATED: Implemented Logic ---
    func updateStudentNote(instructorID: String, studentID: String, oldNote: StudentNote, newContent: String, isOffline: Bool) async throws {
        let ref: DocumentReference
        if isOffline {
            ref = offlineStudentsCollection.document(studentID)
        } else {
            ref = usersCollection.document(instructorID).collection("student_records").document(studentID)
        }
        
        let doc = try await ref.getDocument()
        if doc.exists {
            var notesToUpdate: [StudentNote] = []
            
            if isOffline {
                if let student = try? doc.data(as: OfflineStudent.self), let notes = student.notes {
                    notesToUpdate = notes
                }
            } else {
                if let record = try? doc.data(as: StudentRecord.self), let notes = record.notes {
                    notesToUpdate = notes
                }
            }
            
            // Find the index of the old note
            if let index = notesToUpdate.firstIndex(where: { $0.id == oldNote.id }) {
                // Update content but keep ID and timestamp
                let updatedNote = StudentNote(id: oldNote.id, content: newContent, timestamp: oldNote.timestamp)
                notesToUpdate[index] = updatedNote
                
                // Encode and save back
                let encodedNotes = try notesToUpdate.map { try Firestore.Encoder().encode($0) }
                try await ref.updateData(["notes": encodedNotes])
            }
        }
    }
    
    func fetchInstructorStudentData(instructorID: String, studentID: String, isOffline: Bool) async throws -> StudentRecord? {
        if isOffline {
            let doc = try await offlineStudentsCollection.document(studentID).getDocument()
            guard let off = try? doc.data(as: OfflineStudent.self) else { return nil }
            return StudentRecord(id: studentID, progress: off.progress, notes: off.notes)
        } else {
            let doc = try await usersCollection.document(instructorID).collection("student_records").document(studentID).getDocument()
            return try? doc.data(as: StudentRecord.self)
        }
    }
}
