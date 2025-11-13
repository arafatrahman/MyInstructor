import SwiftUI

// Flow Item 19: Create Post
struct CreatePostView: View {
    @EnvironmentObject var authManager: AuthManager
    @EnvironmentObject var communityManager: CommunityManager
    @Environment(\.dismiss) var dismiss
    
    var onPostCreated: () -> Void

    @State private var postType: PostType = .text
    @State private var content: String = ""
    @State private var mediaURL: String? = nil
    @State private var visibility: PostVisibility = .public
    
    @State private var isLoading = false
    @State private var errorMessage: String?
    
    var visibilityOptions: [PostVisibility] {
        authManager.role == .instructor ? [.public, .instructors, .students, .private] : [.public, .private]
    }

    var body: some View {
        NavigationView {
            Form {
                // Post Type Tabs
                Picker("Post Type", selection: $postType) {
                    Text("🗣️ Text").tag(PostType.text)
                    Text("📸 Media").tag(PostType.photoVideo)
                    Text("❓ Q&A").tag(PostType.qna)
                }
                .pickerStyle(.segmented)
                .padding(.bottom, 10)
                
                // Form Fields (Content)
                Section("Content") {
                    TextEditor(text: $content)
                        .frame(minHeight: 150)
                        .overlay(alignment: .topLeading) {
                            if content.isEmpty {
                                Text("What's on your mind?")
                                    .foregroundColor(Color(.placeholderText))
                                    .padding(.top, 8)
                                    .padding(.leading, 5)
                            }
                        }

                    // Media Upload (Placeholder)
                    if postType == .photoVideo {
                        Button("Upload Photo/Video") {
                            // TODO: Implement image picker
                            mediaURL = "placeholder_media_url"
                        }
                        .foregroundColor(.accentGreen)
                    }
                }
                
                // Settings
                Section("Privacy & Settings") {
                    // Visibility
                    Picker("Visibility", selection: $visibility) {
                        ForEach(visibilityOptions, id: \.self) { option in
                            Text(option.rawValue.capitalized).tag(option)
                        }
                    }
                    
                    HStack {
                        Image(systemName: "location.fill")
                        Text("Add Location (Optional)")
                    }
                }
                
                if let error = errorMessage {
                    Text(error).foregroundColor(.warningRed)
                }
            }
            .navigationTitle("Create Post")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button { publishPost() } label: {
                        if isLoading {
                            ProgressView() // Will use accent color
                        } else {
                            Text("Publish").bold() // Make text bold
                        }
                    }
                    // .buttonStyle(.primaryDrivingApp) // <-- REMOVED
                    .disabled(content.isEmpty || isLoading)
                }
            }
        }
    }
    
    // MARK: - Actions
    
    private func publishPost() {
        guard let userID = authManager.user?.id, let userName = authManager.user?.name else { return }
        isLoading = true
        errorMessage = nil
        
        let newPost = Post(
            authorID: userID,
            authorName: userName,
            authorRole: authManager.role,
            timestamp: Date(),
            content: content,
            mediaURL: mediaURL,
            postType: postType,
            visibility: visibility
        )
        
        Task {
            do {
                try await communityManager.createPost(post: newPost)
                onPostCreated()
                dismiss()
            } catch {
                errorMessage = "Failed to publish post: \(error.localizedDescription)"
            }
            isLoading = false
        }
    }
}
