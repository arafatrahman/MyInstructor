import Foundation
import FirebaseFirestore

// MARK: - Community Models

struct Post: Identifiable, Codable {
    @DocumentID var id: String?
    let authorID: String
    let authorName: String
    var authorRole: UserRole 
    let timestamp: Date
    var content: String?
    var mediaURL: String?
    var postType: PostType
    var reactionsCount: [String: Int] = ["thumbsup": 0, "fire": 0, "heart": 0]
    var commentsCount: Int = 0
    var visibility: PostVisibility = .public
}

enum PostType: String, Codable {
    case text, photoVideo, progressUpdate, qna
}

enum PostVisibility: String, Codable {
    case `public`, instructors, students, `private`
}

struct Comment: Identifiable, Codable {
    @DocumentID var id: String?
    let postID: String
    let authorID: String
    let authorName: String
    let timestamp: Date
    let content: String
    var repliesCount: Int = 0
}
