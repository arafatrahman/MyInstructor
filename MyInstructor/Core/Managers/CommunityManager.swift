import Combine
import Foundation
import FirebaseFirestore

class CommunityManager: ObservableObject {
    private let db = Firestore.firestore()
    private let postsCollection = "community_posts"

    // Fetches recent community posts based on filters (Mocked)
    func fetchPosts(filter: String) async throws -> [Post] {
        try await Task.sleep(nanoseconds: 500_000_000)
        
        let mockPost1 = Post(
            authorID: "i_123", authorName: "Mr. Smith (Instructor)", authorRole: .instructor,
            timestamp: Date().addingTimeInterval(-3600*2),
            content: "Just had a great lesson on clutch control! Remember, slow and steady pressure on the bite point is key. Keep practicing, everyone! #DrivingTips",
            postType: .text, reactionsCount: ["thumbsup": 5, "fire": 2], commentsCount: 1
        )
        
        let mockPost2 = Post(
            authorID: "s_456", authorName: "Emma Watson (Student)", authorRole: .student,
            timestamp: Date().addingTimeInterval(-3600*10),
            content: "Passed my theory test! Huge thanks to Mr. Smith for the motivation! Feeling ready for the practical. 🔥🔥",
            postType: .text, reactionsCount: ["fire": 5, "thumbsup": 10], commentsCount: 3
        )
        
        return [mockPost1, mockPost2].sorted(by: { $0.timestamp > $1.timestamp })
    }
    
    func createPost(post: Post) async throws {
        // In a real app: try db.collection(postsCollection).addDocument(from: post)
        try await Task.sleep(nanoseconds: 300_000_000)
        print("Post created successfully by \(post.authorName)")
    }

    func fetchInstructorDirectory(filters: [String: Any]) async throws -> [Student] {
        try await Task.sleep(nanoseconds: 500_000_000)
        
        // Mock data for directory
        return [
            Student(id: "i_smith", userID: "i_smith", name: "Mr. Adam Smith", email: "smith@drive.com", averageProgress: 0.95),
            Student(id: "i_jones", userID: "i_jones", name: "Ms. Sarah Jones", email: "jones@drive.com", averageProgress: 0.88)
        ]
    }
}
