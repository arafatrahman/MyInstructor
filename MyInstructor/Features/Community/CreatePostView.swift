// File: arafatrahman/myinstructor/MyInstructor-main/MyInstructor/Features/Community/CreatePostView.swift
import SwiftUI
import PhotosUI // --- ADD THIS ---

// Flow Item 19: Create Post
struct CreatePostView: View {
    @EnvironmentObject var authManager: AuthManager
    @EnvironmentObject var communityManager: CommunityManager
    @Environment(\.dismiss) var dismiss
    
    var onPostCreated: () -> Void

    @State private var postType: PostType = .text
    @State private var content: String = ""
    // mediaURL is now set by the uploader
    @State private var visibility: PostVisibility = .public
    
    // --- ADD THESE STATE VARIABLES ---
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var selectedPhotoData: Data?
    @State private var isUploadingMedia = false // To show a separate loader
    // --- END OF ADDITIONS ---
    
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

                    // --- THIS SECTION IS MODIFIED ---
                    if postType == .photoVideo {
                        PhotosPicker(
                            selection: $selectedPhotoItem,
                            matching: .images, // You can expand to .videos later
                            photoLibrary: .shared()
                        ) {
                            HStack(spacing: 12) {
                                // Show selected image
                                if let photoData = selectedPhotoData, let uiImage = UIImage(data: photoData) {
                                    Image(uiImage: uiImage)
                                        .resizable()
                                        .scaledToFill()
                                        .frame(width: 60, height: 60)
                                        .cornerRadius(8)
                                } else {
                                    // Placeholder icon
                                    Image(systemName: "photo.on.rectangle.angled")
                                        .font(.title)
                                        .frame(width: 60, height: 60)
                                        .background(Color.secondaryGray)
                                        .cornerRadius(8)
                                }
                                
                                VStack(alignment: .leading) {
                                    Text(selectedPhotoData == nil ? "Add Photo" : "Change Photo")
                                        .font(.headline)
                                        .foregroundColor(.accentGreen)
                                    if selectedPhotoData != nil {
                                        Text("Photo selected")
                                            .font(.caption)
                                            .foregroundColor(.textLight)
                                    }
                                }
                                
                                Spacer()
                                
                                if isUploadingMedia {
                                    ProgressView().padding(.leading)
                                }
                            }
                            .padding(.vertical, 8)
                        }
                        .onChange(of: selectedPhotoItem) { newItem in
                            Task {
                                isUploadingMedia = true
                                errorMessage = nil
                                if let data = try? await newItem?.loadTransferable(type: Data.self) {
                                    selectedPhotoData = data
                                } else if newItem != nil {
                                    errorMessage = "Could not load selected photo."
                                }
                                isUploadingMedia = false
                            }
                        }
                    }
                    // --- END OF MODIFICATION ---
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
                    .foregroundColor(.textLight) // Make it look disabled
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
                    .disabled(isLoading || isUploadingMedia) // Disable while saving or loading
                }
            }
        }
    }
    
    // MARK: - Actions
    
    // --- THIS FUNCTION IS FULLY REPLACED ---
    private func publishPost() {
        guard let userID = authManager.user?.id, let userName = authManager.user?.name else {
            errorMessage = "Error: Could not find user."
            return
        }
        
        // Validate content
        let trimmedContent = content.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmedContent.isEmpty && selectedPhotoData == nil {
            errorMessage = "Please write something or select a photo to post."
            return
        }
        
        // Ensure post type matches content
        if postType == .photoVideo && selectedPhotoData == nil {
            errorMessage = "Please select a photo for a media post."
            return
        }
        
        isLoading = true
        errorMessage = nil
        
        // This is the new, combined task
        Task {
            do {
                var finalMediaURL: String? = nil
                
                // 1. If photo data exists, upload it
                if let photoData = selectedPhotoData {
                    print("Photo data found, attempting upload...")
                    
                    finalMediaURL = try await StorageManager.shared.uploadPostMedia(
                        photoData: photoData,
                        userID: userID
                    )
                }

                // 2. Create the Post object
                let newPost = Post(
                    authorID: userID,
                    authorName: userName,
                    authorRole: authManager.role,
                    timestamp: Date(),
                    content: trimmedContent.isEmpty ? nil : trimmedContent, // Store nil if empty
                    mediaURL: finalMediaURL, // Use the URL from upload
                    postType: postType,
                    visibility: visibility
                )
                
                // 3. Save the Post object to Firestore
                try await communityManager.createPost(post: newPost)
                
                // 4. Success: Call handler and dismiss
                onPostCreated()
                dismiss()
                
            } catch {
                errorMessage = "Failed to publish post: \(error.localizedDescription)"
                isLoading = false
            }
            // isLoading is set to false (or view is dismissed)
        }
    }
    // --- END OF REPLACEMENT ---
}
