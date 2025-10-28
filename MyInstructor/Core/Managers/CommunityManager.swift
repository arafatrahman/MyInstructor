import Combine
import Foundation
import FirebaseFirestore

class CommunityManager: ObservableObject {
    private let db = Firestore.firestore()
    private var postsCollection: CollectionReference {
        db.collection("community_posts")
    }
    private var usersCollection: CollectionReference {
        db.collection("users")
    }

    // Fetches recent community posts based on filters
    func fetchPosts(filter: String) async throws -> [Post] {
        // TODO: Implement actual filter logic based on the 'filter' string.
        // This example just fetches the 20 newest posts.
        let snapshot = try await postsCollection
            .order(by: "timestamp", descending: true)
            .limit(to: 20)
            .getDocuments()
        
        // Use compactMap to safely decode posts
        let posts = snapshot.documents.compactMap { document in
            try? document.data(as: Post.self)
        }
        return posts
    }
    
    func createPost(post: Post) async throws {
        // Use `addDocument(from:)` to encode the Post object
        try postsCollection.addDocument(from: post)
        print("Post created successfully by \(post.authorName)")
    }

    // Fetches instructors from the 'users' collection
    func fetchInstructorDirectory(filters: [String: Any]) async throws -> [Student] {
        // TODO: Implement advanced filtering based on the 'filters' dictionary.
        // This example just fetches all users marked as 'instructor'.
        let snapshot = try await usersCollection
            .whereField("role", isEqualTo: UserRole.instructor.rawValue)
            .limit(to: 20)
            .getDocuments()
            
        // We are mapping AppUser data to the Student model for the directory list.
        // This is a bit of a mismatch but follows the original mock's structure.
        let instructors = snapshot.documents.compactMap { document -> Student? in
            guard let appUser = try? document.data(as: AppUser.self) else { return nil }
            // Create a 'Student' object from the 'AppUser' data for the directory list
            return Student(
                id: appUser.id,
                userID: appUser.id ?? "unknown_user_id",
                name: appUser.name ?? "Instructor",
                photoURL: appUser.photoURL,
                email: appUser.email,
                drivingSchool: appUser.drivingSchool
                // Note: averageProgress is not on AppUser, so it defaults to 0.0
            )
        }
        return instructors
    }
}
