// File: arafatrahman/myinstructor/MyInstructor-main/MyInstructor/Features/Community/CreatePostView.swift
// --- UPDATED: Removed PostType Picker for a single, unified creation flow ---

import SwiftUI
import PhotosUI // Make sure this is imported

// Flow Item 19: Create Post
struct CreatePostView: View {
    @EnvironmentObject var authManager: AuthManager
    @EnvironmentObject var communityManager: CommunityManager
    @Environment(\.dismiss) var dismiss
    
    var onPostCreated: () -> Void

    // --- REMOVED ---
    // @State private var postType: PostType = .text
    
    @State private var content: String = ""
    @State private var visibility: PostVisibility = .public
    
    @State private var isLoading = false
    @State private var errorMessage: String?
    
    // --- STATE FOR NEW PHOTO PICKER ---
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var selectedPhotoData: Data?
    @State private var isUploadingMedia = false // To show a separate loader
    
    var visibilityOptions: [PostVisibility] {
        authManager.role == .instructor ? [.public, .instructors, .students, .private] : [.public, .private]
    }

    var body: some View {
        NavigationView {
            Form {
                
                // --- REMOVED PICKER ---
                
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
                }
                
                // --- NEW UNCONDITIONAL MEDIA SECTION ---
                Section("Media (Optional)") {
                    PhotosPicker(
                        selection: $selectedPhotoItem,
                        matching: .images,
                        photoLibrary: .shared()
                    ) {
                        // This is the "button" part
                        HStack(spacing: 12) {
                            Image(systemName: "photo.on.rectangle.angled")
                                .font(.title)
                                .frame(width: 40)
                                .foregroundColor(.accentGreen)
                            
                            Text(selectedPhotoData == nil ? "Add Photo" : "Change Photo")
                                .font(.headline)
                                .foregroundColor(.accentGreen)
                            
                            Spacer()
                            
                            if isUploadingMedia {
                                ProgressView()
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
                            } else {
                                // User cleared selection
                                selectedPhotoData = nil
                            }
                            isUploadingMedia = false
                        }
                    }
                    
                    // This is the "preview" part
                    if let photoData = selectedPhotoData, let uiImage = UIImage(data: photoData) {
                        Image(uiImage: uiImage)
                            .resizable()
                            .scaledToFit()
                            .cornerRadius(10)
                            .padding(.vertical, 5)
                            // Add a context menu (long press) to remove
                            .contextMenu {
                                Button(role: .destructive) {
                                    withAnimation {
                                        selectedPhotoItem = nil
                                        selectedPhotoData = nil
                                    }
                                } label: {
                                    Label("Remove Photo", systemImage: "xmark.circle.fill")
                                }
                            }
                    }
                }
                // --- END OF NEW SECTION ---
                
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
                    .foregroundColor(.textLight)
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
                    // Disable while saving or loading
                    .disabled(isLoading || isUploadingMedia)
                }
            }
        }
    }
    
    // MARK: - Actions
    
    // --- THIS FUNCTION IS UPDATED ---
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
                
                // 2. Determine PostType implicitly
                let finalPostType: PostType
                if finalMediaURL != nil {
                    // If there's a photo, it's a photoVideo post
                    finalPostType = .photoVideo
                } else {
                    // Otherwise, it's a text post
                    finalPostType = .text
                }

                // 3. Create the Post object
                let newPost = Post(
                    authorID: userID,
                    authorName: userName,
                    authorRole: authManager.role,
                    timestamp: Date(),
                    content: trimmedContent.isEmpty ? nil : trimmedContent, // Store nil if empty
                    mediaURL: finalMediaURL, // Use the URL from upload
                    postType: finalPostType, // Use the new implicit type
                    visibility: visibility
                )
                
                // 4. Save the Post object to Firestore
                try await communityManager.createPost(post: newPost)
                
                // 5. Success: Call handler and dismiss
                onPostCreated()
                dismiss()
                
            } catch {
                errorMessage = "Failed to publish post: \(error.localizedDescription)"
                isLoading = false
            }
            // isLoading is set to false (or view is dismissed)
        }
    }
    // --- END OF UPDATE ---
}
