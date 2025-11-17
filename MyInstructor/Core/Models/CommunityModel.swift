// File: arafatrahman/myinstructor/MyInstructor-main/MyInstructor/Core/Models/CommunityModel.swift

import Foundation
import FirebaseFirestore

// MARK: - Community Models

struct Post: Identifiable, Codable {
    @DocumentID var id: String?
    let authorID: String
    let authorName: String
    var authorRole: UserRole
    let authorPhotoURL: String?
    let timestamp: Date
    var content: String?
    var mediaURLs: [String]?
    var location: String?
    var postType: PostType
    var reactionsCount: [String: Int] = ["thumbsup": 0, "fire": 0, "heart": 0]
    var commentsCount: Int = 0
    var visibility: PostVisibility = .public
    
    // --- *** ADD THIS LINE *** ---
    var isEdited: Bool? = false
}

enum PostType: String, Codable {
    case text, photoVideo, progressUpdate, qna
}

enum PostVisibility: String, Codable {
    case `public`, instructors, students, `private`
}

// --- THIS STRUCT IS UPDATED ---
struct Comment: Identifiable, Codable, Equatable {
    @DocumentID var id: String?
    let postID: String
    let authorID: String
    let authorName: String
    
    // --- NEW FIELDS ---
    let authorPhotoURL: String?
    let authorRole: UserRole
    // --- ---
    
    let timestamp: Date
    let content: String
    
    // --- NEW FIELD for replies ---
    var parentCommentID: String?
    
    var repliesCount: Int = 0
}
