// File: arafatrahman/myinstructor/MyInstructor-main/MyInstructor/Core/Managers/CommunityManager.swift
// --- UPDATED: Added 'listenToCommentsForPost' for individual Feed Cards ---

import Combine
import Foundation
import FirebaseFirestore
import FirebaseStorage

enum FeedAlgorithm: String, CaseIterable, Identifiable {
    case latest = "Latest"
    case trending = "Trending"
    case viral = "Viral"
    case influential = "Influential"
    case regularity = "Regularity"
    
    var id: String { self.rawValue }
}

class CommunityManager: ObservableObject {
    private let db = Firestore.firestore()
    
    private var postsCollection: CollectionReference { db.collection("community_posts") }
    private var usersCollection: CollectionReference { db.collection("users") }
    private var requestsCollection: CollectionReference { db.collection("student_requests") }
    private var conversationsCollection: CollectionReference { db.collection("conversations") }
    private var offlineStudentsCollection: CollectionReference { db.collection("offline_students") }
    
    @Published var posts: [Post] = []
    @Published var comments: [Comment] = [] // For PostDetailView (Single source)
    @Published var activeUserCount: Int = 0
    
    private var authorCache: [String: AppUser] = [:]
    
    private var postsListener: ListenerRegistration?
    private var commentsListener: ListenerRegistration?
    
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

    // MARK: - Community Posts (Real-time & Algorithmic)
    
    func listenToFeed(algorithm: FeedAlgorithm) {
        postsListener?.remove()
        let query = postsCollection.order(by: "timestamp", descending: true).limit(to: 50)
        
        postsListener = query.addSnapshotListener { [weak self] snapshot, error in
            guard let self = self else { return }
            if let error = error { print("Error listening to feed: \(error.localizedDescription)"); return }
            guard let documents = snapshot?.documents else { return }
            
            let fetchedPosts = documents.compactMap { try? $0.data(as: Post.self) }
            
            Task {
                let uniqueAuthors = Set(fetchedPosts.map { $0.authorID })
                await MainActor.run { self.activeUserCount = uniqueAuthors.count }
                let sortedPosts = await self.applyAlgorithm(fetchedPosts, algorithm: algorithm)
                await MainActor.run { self.posts = sortedPosts }
            }
        }
    }
    
    private func applyAlgorithm(_ posts: [Post], algorithm: FeedAlgorithm) async -> [Post] {
        switch algorithm {
        case .latest:
            return posts.sorted(by: { $0.timestamp > $1.timestamp })
        case .trending:
            return posts.sorted { calculateTrendingScore($0) > calculateTrendingScore($1) }
        case .viral:
            return posts.sorted { calculateViralVelocity($0) > calculateViralVelocity($1) }
        case .influential:
            await fetchMissingAuthors(for: posts)
            return posts.sorted {
                (authorCache[$0.authorID]?.followers?.count ?? 0) > (authorCache[$1.authorID]?.followers?.count ?? 0)
            }
        case .regularity:
            let counts = posts.reduce(into: [String: Int]()) { $0[$1.authorID, default: 0] += 1 }
            return posts.sorted {
                let c1 = counts[$0.authorID] ?? 0, c2 = counts[$1.authorID] ?? 0
                return c1 == c2 ? $0.timestamp > $1.timestamp : c1 > c2
            }
        }
    }
    
    private func calculateTrendingScore(_ post: Post) -> Double {
        let engagement = Double(post.reactionsCount.values.reduce(0, +)) + (Double(post.commentsCount) * 2.0)
        let hoursSincePost = abs(Date().timeIntervalSince(post.timestamp)) / 3600.0
        return engagement / pow((hoursSincePost + 2.0), 1.5)
    }
    
    private func calculateViralVelocity(_ post: Post) -> Double {
        let engagement = Double(post.reactionsCount.values.reduce(0, +) + post.commentsCount)
        let hours = max(0.1, abs(Date().timeIntervalSince(post.timestamp)) / 3600.0)
        return engagement / hours
    }
    
    private func fetchMissingAuthors(for posts: [Post]) async {
        let missingIDs = Set(posts.map { $0.authorID }).subtracting(authorCache.keys)
        guard !missingIDs.isEmpty else { return }
        let chunks = stride(from: 0, to: missingIDs.count, by: 10).map { Array(Array(missingIDs)[$0..<min($0 + 10, missingIDs.count)]) }
        for chunk in chunks {
            if let snapshot = try? await usersCollection.whereField(FieldPath.documentID(), in: chunk).getDocuments() {
                for doc in snapshot.documents {
                    if let user = try? doc.data(as: AppUser.self) { authorCache[user.id ?? ""] = user }
                }
            }
        }
    }
    
    func stopListeningToFeed() { postsListener?.remove(); postsListener = nil }
    
    func createPost(post: Post) async throws {
        try postsCollection.addDocument(from: post)
        let authorDoc = try await usersCollection.document(post.authorID).getDocument()
        if let author = try? authorDoc.data(as: AppUser.self), let followers = author.followers {
            for followerID in followers {
                NotificationManager.shared.sendNotification(to: followerID, title: "New Post", message: "\(author.name ?? "A user") you follow just posted.", type: "post", relatedID: nil)
            }
        }
    }
    
    func deletePost(postID: String) async throws { try await postsCollection.document(postID).delete() }

    func updatePostDetails(postID: String, content: String?, location: String?, visibility: PostVisibility, newMediaURLs: [String]?) async throws {
        var data: [String: Any] = ["visibility": visibility.rawValue, "isEdited": true]
        if let content = content { data["content"] = content }
        if let location = location { data["location"] = location }
        if let urls = newMediaURLs { data["mediaURLs"] = urls }
        try await postsCollection.document(postID).updateData(data)
    }
    
    func fetchInstructorDirectory(filters: [String: Any]) async throws -> [Student] {
        let snapshot = try await usersCollection.whereField("role", isEqualTo: UserRole.instructor.rawValue).limit(to: 20).getDocuments()
        return snapshot.documents.compactMap { try? $0.data(as: AppUser.self) }.map { appUser in
            Student(id: appUser.id, userID: appUser.id ?? "", name: appUser.name ?? "Instructor", photoURL: appUser.photoURL, email: appUser.email, drivingSchool: appUser.drivingSchool, phone: appUser.phone, address: appUser.address)
        }
    }
    
    func addReaction(postID: String, user: AppUser, reactionType: String) async throws {
        try await postsCollection.document(postID).updateData(["reactionsCount.\(reactionType)": FieldValue.increment(1.0)])
        if let doc = try? await postsCollection.document(postID).getDocument(), let post = try? doc.data(as: Post.self), post.authorID != user.id {
            NotificationManager.shared.sendNotification(to: post.authorID, title: "New Reaction", message: "\(user.name ?? "Someone") reacted to your post.", type: "reaction")
        }
    }
    
    func followUser(currentUserID: String, targetUserID: String, currentUserName: String) async throws {
        try await usersCollection.document(currentUserID).updateData(["following": FieldValue.arrayUnion([targetUserID])])
        try await usersCollection.document(targetUserID).updateData(["followers": FieldValue.arrayUnion([currentUserID])])
        NotificationManager.shared.sendNotification(to: targetUserID, title: "New Follower", message: "\(currentUserName) started following you.", type: "follow", relatedID: currentUserID)
    }
    
    func unfollowUser(currentUserID: String, targetUserID: String) async throws {
        try await usersCollection.document(currentUserID).updateData(["following": FieldValue.arrayRemove([targetUserID])])
        try await usersCollection.document(targetUserID).updateData(["followers": FieldValue.arrayRemove([currentUserID])])
    }
    
    func blockUserGeneric(blockerID: String, targetID: String) async throws {
        try await usersCollection.document(blockerID).updateData(["blockedUsers": FieldValue.arrayUnion([targetID])])
        try await unfollowUser(currentUserID: blockerID, targetUserID: targetID)
        try await unfollowUser(currentUserID: targetID, targetUserID: blockerID)
    }
    
    func unblockUserGeneric(blockerID: String, targetID: String) async throws {
        try await usersCollection.document(blockerID).updateData(["blockedUsers": FieldValue.arrayRemove([targetID])])
    }
    
    // MARK: - Comment System
    
    // --- THIS IS FOR POST DETAILS VIEW (Single Post) ---
    func listenToComments(for postID: String) {
        commentsListener?.remove()
        commentsListener = postsCollection.document(postID).collection("comments").order(by: "timestamp", descending: false).addSnapshotListener { [weak self] snapshot, _ in
            guard let self = self, let docs = snapshot?.documents else { return }
            self.comments = docs.compactMap { try? $0.data(as: Comment.self) }
        }
    }
    
    func stopListeningToComments() { commentsListener?.remove(); commentsListener = nil; comments = [] }
    
    // --- *** NEW: THIS IS FOR COMMUNITY FEED (Multiple Posts) *** ---
    // Returns a listener registration so individual PostCards can manage their own connection
    func listenToCommentsForPost(postID: String, onUpdate: @escaping ([Comment]) -> Void) -> ListenerRegistration {
        return postsCollection.document(postID).collection("comments")
            .order(by: "timestamp", descending: false)
            .addSnapshotListener { snapshot, error in
                if let error = error {
                    print("Error listening to comments for post \(postID): \(error.localizedDescription)")
                    return
                }
                guard let documents = snapshot?.documents else { return }
                let comments = documents.compactMap { try? $0.data(as: Comment.self) }
                onUpdate(comments)
            }
    }
    
    func fetchComments(for postID: String) async throws -> [Comment] {
        let snapshot = try await postsCollection.document(postID).collection("comments").order(by: "timestamp", descending: false).getDocuments()
        return snapshot.documents.compactMap { try? $0.data(as: Comment.self) }
    }
    
    func addComment(postID: String, authorID: String, authorName: String, authorRole: UserRole, authorPhotoURL: String?, content: String, parentCommentID: String?) async throws {
        let newComment = Comment(
            postID: postID,
            authorID: authorID,
            authorName: authorName,
            authorPhotoURL: authorPhotoURL,
            authorRole: authorRole,
            timestamp: Date(),
            content: content,
            parentCommentID: parentCommentID,
            isEdited: false
        )
        try postsCollection.document(postID).collection("comments").addDocument(from: newComment)
        try await postsCollection.document(postID).updateData(["commentsCount": FieldValue.increment(1.0)])
        
        if let parentID = parentCommentID {
            try? await postsCollection.document(postID).collection("comments").document(parentID).updateData(["repliesCount": FieldValue.increment(1.0)])
        }
        
        let postDoc = try await postsCollection.document(postID).getDocument()
        guard let post = try? postDoc.data(as: Post.self) else { return }
        if let parentID = parentCommentID, let parentDoc = try? await postsCollection.document(postID).collection("comments").document(parentID).getDocument(), let parentComment = try? parentDoc.data(as: Comment.self), parentComment.authorID != authorID {
            NotificationManager.shared.sendNotification(to: parentComment.authorID, title: "New Reply", message: "\(authorName) replied to your comment.", type: "reply")
        } else if post.authorID != authorID {
            NotificationManager.shared.sendNotification(to: post.authorID, title: "New Comment", message: "\(authorName) commented on your post.", type: "comment")
        }
    }
    
    func deleteComment(postID: String, commentID: String, parentCommentID: String?) async throws {
        try await postsCollection.document(postID).collection("comments").document(commentID).delete()
        try await postsCollection.document(postID).updateData(["commentsCount": FieldValue.increment(-1.0)])
        if let parentID = parentCommentID {
            try? await postsCollection.document(postID).collection("comments").document(parentID).updateData(["repliesCount": FieldValue.increment(-1.0)])
        }
    }
    
    func updateComment(postID: String, commentID: String, newContent: String) async throws {
        try await postsCollection.document(postID).collection("comments").document(commentID).updateData(["content": newContent, "isEdited": true])
    }
    
    // ... (Rest of the class remains unchanged: relationships, requests, student management) ...
    
    func fetchRelationshipStatus(instructorID: String, studentID: String) async throws -> RequestStatus? {
        let query = requestsCollection.whereField("studentID", isEqualTo: studentID).whereField("instructorID", isEqualTo: instructorID)
        return try? (await query.getDocuments()).documents.first?.data(as: StudentRequest.self).status
    }
    
    func fetchAllRelationships(for instructorID: String) async throws -> [StudentRequest] {
        let query = requestsCollection.whereField("instructorID", isEqualTo: instructorID)
        return try await query.getDocuments().documents.compactMap { try? $0.data(as: StudentRequest.self) }
    }
    
    func sendRequest(from student: AppUser, to instructorID: String) async throws {
        let query = requestsCollection.whereField("studentID", isEqualTo: student.id!).whereField("instructorID", isEqualTo: instructorID)
        if let existing = (try await query.getDocuments()).documents.first, let status = try? existing.data(as: StudentRequest.self).status {
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
    
    func approveRequest(_ request: StudentRequest) async throws {
        guard let id = request.id else { return }
        try await requestsCollection.document(id).updateData(["status": RequestStatus.approved.rawValue])
        try await usersCollection.document(request.instructorID).updateData(["studentIDs": FieldValue.arrayUnion([request.studentID])])
        try await usersCollection.document(request.studentID).updateData(["instructorIDs": FieldValue.arrayUnion([request.instructorID])])
    }
    
    func denyRequest(_ request: StudentRequest) async throws {
        guard let id = request.id else { return }
        try await requestsCollection.document(id).updateData(["status": RequestStatus.denied.rawValue])
    }
    
    func removeStudent(studentID: String, instructorID: String) async throws {
        let snapshot = try await requestsCollection.whereField("studentID", isEqualTo: studentID).whereField("instructorID", isEqualTo: instructorID).getDocuments()
        for doc in snapshot.documents { try await doc.reference.updateData(["status": RequestStatus.completed.rawValue]) }
    }
    
    func reactivateStudent(studentID: String, instructorID: String) async throws {
        let snapshot = try await requestsCollection.whereField("studentID", isEqualTo: studentID).whereField("instructorID", isEqualTo: instructorID).getDocuments()
        for doc in snapshot.documents { try await doc.reference.updateData(["status": RequestStatus.approved.rawValue]) }
    }
    
    func blockStudent(studentID: String, instructorID: String) async throws {
        let snapshot = try await requestsCollection.whereField("studentID", isEqualTo: studentID).whereField("instructorID", isEqualTo: instructorID).getDocuments()
        if let doc = snapshot.documents.first { try await doc.reference.updateData(["status": RequestStatus.blocked.rawValue, "blockedBy": "instructor"]) }
        else { try requestsCollection.addDocument(from: StudentRequest(studentID: studentID, studentName: "Blocked", studentPhotoURL: nil, instructorID: instructorID, status: .blocked, timestamp: Date(), blockedBy: "instructor")) }
        try await usersCollection.document(instructorID).updateData(["studentIDs": FieldValue.arrayRemove([studentID])])
        try await usersCollection.document(studentID).updateData(["instructorIDs": FieldValue.arrayRemove([instructorID])])
    }
    
    func unblockStudent(studentID: String, instructorID: String) async throws {
        let snapshot = try await requestsCollection.whereField("studentID", isEqualTo: studentID).whereField("instructorID", isEqualTo: instructorID).getDocuments()
        for doc in snapshot.documents { try await doc.reference.updateData(["status": RequestStatus.approved.rawValue, "blockedBy": FieldValue.delete()]) }
        try await usersCollection.document(instructorID).updateData(["studentIDs": FieldValue.arrayUnion([studentID])])
        try await usersCollection.document(studentID).updateData(["instructorIDs": FieldValue.arrayUnion([instructorID])])
    }
    
    func blockInstructor(instructorID: String, student: AppUser) async throws {
        guard let studentID = student.id else { return }
        let snapshot = try await requestsCollection.whereField("studentID", isEqualTo: studentID).whereField("instructorID", isEqualTo: instructorID).getDocuments()
        if let doc = snapshot.documents.first { try await doc.reference.updateData(["status": RequestStatus.blocked.rawValue, "blockedBy": "student"]) }
        else { try requestsCollection.addDocument(from: StudentRequest(studentID: studentID, studentName: student.name ?? "", studentPhotoURL: student.photoURL, instructorID: instructorID, status: .blocked, timestamp: Date(), blockedBy: "student")) }
    }
    
    func unblockInstructor(instructorID: String, studentID: String) async throws {
        let snapshot = try await requestsCollection.whereField("studentID", isEqualTo: studentID).whereField("instructorID", isEqualTo: instructorID).getDocuments()
        for doc in snapshot.documents { try await doc.reference.updateData(["status": RequestStatus.approved.rawValue, "blockedBy": FieldValue.delete()]) }
    }
    
    func removeInstructor(instructorID: String, studentID: String) async throws { try await removeStudent(studentID: studentID, instructorID: instructorID) }
    
    func fetchSentRequests(for studentID: String) async throws -> [StudentRequest] {
        let snapshot = try await requestsCollection.whereField("studentID", isEqualTo: studentID).getDocuments()
        return snapshot.documents.compactMap { try? $0.data(as: StudentRequest.self) }
    }
    
    func cancelRequest(requestID: String) async throws { try await requestsCollection.document(requestID).delete() }
    
    func addOfflineStudent(instructorID: String, name: String, phone: String?, email: String?, address: String?) async throws {
        var newStudent = OfflineStudent(instructorID: instructorID, name: name, phone: phone, email: email, address: address)
        newStudent.id = nil
        try offlineStudentsCollection.addDocument(from: newStudent)
    }
    
    func updateOfflineStudent(_ student: OfflineStudent) async throws {
        guard let id = student.id else { return }
        try offlineStudentsCollection.document(id).setData(from: student)
    }

    func deleteOfflineStudent(studentID: String) async throws {
        try await offlineStudentsCollection.document(studentID).delete()
    }
    
    func updateStudentProgress(instructorID: String, studentID: String, newProgress: Double, isOffline: Bool) async throws {
        if isOffline {
            try await offlineStudentsCollection.document(studentID).updateData(["progress": newProgress])
        } else {
            let recordRef = usersCollection.document(instructorID).collection("student_records").document(studentID)
            try await recordRef.setData(["progress": newProgress], merge: true)
            NotificationManager.shared.sendNotification(to: studentID, title: "Progress Updated", message: "Your mastery level has been updated to \(Int(newProgress * 100))%.", type: "progress")
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
            NotificationManager.shared.sendNotification(to: studentID, title: "New Note from Instructor", message: "You received a new note: \"\(noteContent)\"", type: "note")
        }
    }
    
    func deleteStudentNote(instructorID: String, studentID: String, note: StudentNote, isOffline: Bool) async throws {
        let ref: DocumentReference = isOffline ? offlineStudentsCollection.document(studentID) : usersCollection.document(instructorID).collection("student_records").document(studentID)
        let doc = try await ref.getDocument()
        if doc.exists {
            var notesToUpdate: [StudentNote] = []
            if isOffline { if let student = try? doc.data(as: OfflineStudent.self), let notes = student.notes { notesToUpdate = notes } }
            else { if let record = try? doc.data(as: StudentRecord.self), let notes = record.notes { notesToUpdate = notes } }
            let filteredNotes = notesToUpdate.filter { $0.id != note.id }
            let encodedNotes = try filteredNotes.map { try Firestore.Encoder().encode($0) }
            try await ref.updateData(["notes": encodedNotes])
        }
    }
    
    func updateStudentNote(instructorID: String, studentID: String, oldNote: StudentNote, newContent: String, isOffline: Bool) async throws {
        let ref: DocumentReference = isOffline ? offlineStudentsCollection.document(studentID) : usersCollection.document(instructorID).collection("student_records").document(studentID)
        let doc = try await ref.getDocument()
        if doc.exists {
            var notesToUpdate: [StudentNote] = []
            if isOffline { if let student = try? doc.data(as: OfflineStudent.self), let notes = student.notes { notesToUpdate = notes } }
            else { if let record = try? doc.data(as: StudentRecord.self), let notes = record.notes { notesToUpdate = notes } }
            if let index = notesToUpdate.firstIndex(where: { $0.id == oldNote.id }) {
                notesToUpdate[index] = StudentNote(id: oldNote.id, content: newContent, timestamp: oldNote.timestamp)
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
