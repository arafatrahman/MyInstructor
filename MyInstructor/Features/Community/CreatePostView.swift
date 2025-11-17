// File: arafatrahman/myinstructor/MyInstructor-main/MyInstructor/Features/Community/CreatePostView.swift
// --- UPDATED: Now supports adding/removing photos in edit mode ---

import SwiftUI
import PhotosUI

// Flow Item 19: Create Post
struct CreatePostView: View {
    @EnvironmentObject var authManager: AuthManager
    @EnvironmentObject var communityManager: CommunityManager
    @Environment(\.dismiss) var dismiss
    
    let postToEdit: Post?
    var onPostCreated: (() -> Void)? = nil // For creating
    // --- *** MODIFIED: Closure now includes media URLs *** ---
    var onPostSaved: ((String, String?, PostVisibility, [String]?) -> Void)? = nil // For editing
    
    // --- STATE FOR PHOTOS ---
    @State private var internalPhotoItems: [PhotosPickerItem] = []
    @State private var photoDataList: [Data] // For *new* photos
    @State private var editableMediaURLs: [String] // For *existing* photos
    
    // --- OTHER STATE ---
    @State private var content: String = ""
    @State private var visibility: PostVisibility = .public
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var isUploadingMedia = false
    @State private var isShowingAddressSearch = false
    @State private var selectedLocationString: String? = nil
    
    @State private var isEditing: Bool = false
    
    var visibilityOptions: [PostVisibility] {
        [.public, .private]
    }
    
    // --- *** UPDATED INITIALIZER *** ---
    init(postToEdit: Post? = nil, initialPhotoData: [Data] = [], onPostCreated: (() -> Void)? = nil, onPostSaved: ((String, String?, PostVisibility, [String]?) -> Void)? = nil) {
        self.postToEdit = postToEdit
        self.onPostCreated = onPostCreated
        self.onPostSaved = onPostSaved
        
        if let post = postToEdit {
            // Editing: Set initial values from the post
            self._content = State(initialValue: post.content ?? "")
            self._visibility = State(initialValue: post.visibility)
            self._selectedLocationString = State(initialValue: post.location)
            self._isEditing = State(initialValue: true)
            // Store existing URLs
            self._editableMediaURLs = State(initialValue: post.mediaURLs ?? [])
            // New photo list starts empty
            self._photoDataList = State(initialValue: [])
        } else {
            // Creating: Set default values
            self._content = State(initialValue: "")
            self._visibility = State(initialValue: .public)
            self._selectedLocationString = State(initialValue: nil)
            self._isEditing = State(initialValue: false)
            self._editableMediaURLs = State(initialValue: [])
            self._photoDataList = State(initialValue: initialPhotoData)
        }
    }

    var body: some View {
        NavigationView {
            Form {
                
                Section(isEditing ? "Edit your post" : "What's on your mind?") {
                    VStack(alignment: .leading, spacing: 0) {
                        // 1. Text Editor
                        TextEditor(text: $content)
                            .frame(minHeight: 150)
                            .overlay(alignment: .topLeading) {
                                if content.isEmpty {
                                    Text("Share an update with your community...")
                                        .foregroundColor(Color(.placeholderText))
                                        .padding(.top, 8)
                                        .padding(.leading, 5)
                                }
                            }
                        
                        // 2. Horizontal Scrolling Preview
                        
                        // --- *** UPDATED: Show existing photos (if editing) *** ---
                        if isEditing && !editableMediaURLs.isEmpty {
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 8) {
                                    ForEach(Array(editableMediaURLs.enumerated()), id: \.offset) { index, urlString in
                                        ZStack(alignment: .topTrailing) {
                                            AsyncImage(url: URL(string: urlString)) { phase in
                                                if let image = phase.image {
                                                    image.resizable().scaledToFill()
                                                } else { ProgressView() }
                                            }
                                            .frame(width: 100, height: 100)
                                            .cornerRadius(10)
                                            
                                            // Remove Button for existing photos
                                            Button(action: { removeExistingPhoto(at: index) }) {
                                                Image(systemName: "xmark.circle.fill")
                                                    .font(.callout)
                                                    .foregroundColor(.white)
                                                    .background(Color.black.opacity(0.6).clipShape(Circle()))
                                            }
                                            .buttonStyle(.plain)
                                            .padding(4)
                                        }
                                    }
                                }
                                .padding(.top, 10)
                            }
                            .frame(height: 110)
                        }

                        // --- *** Show *newly added* photos (in both create and edit) *** ---
                        if !photoDataList.isEmpty {
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 8) {
                                    ForEach(Array(photoDataList.enumerated()), id: \.offset) { index, photoData in
                                        if let uiImage = UIImage(data: photoData) {
                                            ZStack(alignment: .topTrailing) {
                                                Image(uiImage: uiImage)
                                                    .resizable()
                                                    .scaledToFill()
                                                    .frame(width: 100, height: 100)
                                                    .cornerRadius(10)

                                                // Remove Button for new photos
                                                Button(action: { removeNewPhoto(at: index) }) {
                                                    Image(systemName: "xmark.circle.fill")
                                                        .font(.callout)
                                                        .foregroundColor(.white)
                                                        .background(Color.black.opacity(0.6).clipShape(Circle()))
                                                }
                                                .buttonStyle(.plain)
                                                .padding(4)
                                            }
                                        }
                                    }
                                }
                                .padding(.top, 10)
                            }
                            .frame(height: 110)
                        }

                        // 3. Selected Location
                        if let location = selectedLocationString {
                            HStack(spacing: 8) {
                                Image(systemName: "mappin.and.ellipse")
                                    .foregroundColor(.primaryBlue)
                                Text(location)
                                    .font(.caption)
                                    .lineLimit(1)
                                Spacer()
                                Button(action: removeLocation) {
                                    Image(systemName: "xmark")
                                        .font(.caption)
                                        .foregroundColor(.textLight)
                                }
                                .buttonStyle(.plain)
                            }
                            .padding(8)
                            .background(Color.secondaryGray.opacity(0.5))
                            .cornerRadius(10)
                            .padding(.top, 10)
                        }

                        Divider().padding(.top, 10)
                        
                        // 4. Action Icons
                        HStack(spacing: 25) {
                            // --- *** Photo Picker is no longer disabled in edit mode *** ---
                            PhotosPicker(
                                selection: $internalPhotoItems,
                                maxSelectionCount: 5 - (photoDataList.count + editableMediaURLs.count), // Combined total
                                matching: .images,
                                photoLibrary: .shared()
                            ) {
                                Image(systemName: "photo.on.rectangle.angled")
                                    .font(.title2)
                                    .foregroundColor(.accentGreen)
                                    .contentShape(Rectangle())
                            }
                            .disabled((photoDataList.count + editableMediaURLs.count) >= 5) // Disable if 5 photos total
                            .onChange(of: internalPhotoItems, handleInternalPhotoSelection)
                            
                            Button(action: { isShowingAddressSearch = true }) {
                                Image(systemName: "mappin.and.ellipse")
                                    .font(.title2)
                                    .foregroundColor(.primaryBlue)
                                    .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            
                            Spacer()
                            
                            if isUploadingMedia { ProgressView() }
                        }
                        .padding(.top, 10)
                    }
                }
                
                Section("Privacy & Settings") {
                    Picker("Visibility", selection: $visibility) {
                        ForEach(visibilityOptions, id: \.self) { option in
                            if option == .public {
                                Label("Public", systemImage: "globe").tag(PostVisibility.public)
                            } else if option == .private {
                                Label("Private", systemImage: "lock.fill").tag(PostVisibility.private)
                            }
                        }
                    }
                    .pickerStyle(.segmented)
                }
                
                if let error = errorMessage {
                    Text(error).foregroundColor(.warningRed)
                }
            }
            .navigationTitle(isEditing ? "Edit Post" : "Create Post")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button { publishOrUpdatePost() } label: {
                        if isLoading {
                            ProgressView()
                        } else {
                            Text(isEditing ? "Save" : "Publish").bold()
                        }
                    }
                    .disabled(isLoading || isUploadingMedia) // --- *** MODIFIED *** ---
                }
            }
            .sheet(isPresented: $isShowingAddressSearch) {
                AddressSearchView { selectedAddressString in
                    self.selectedLocationString = selectedAddressString
                }
            }
            .animation(.default, value: photoDataList)
            .animation(.default, value: editableMediaURLs) // <-- ADDED
            .animation(.default, value: selectedLocationString)
        }
    }
    
    // MARK: - Helper Functions
    
    private func handleInternalPhotoSelection(oldItems: [PhotosPickerItem]?, newItems: [PhotosPickerItem]) {
         Task {
            isUploadingMedia = true
            errorMessage = nil
            
            for item in newItems {
                if let data = try? await item.loadTransferable(type: Data.self) {
                    if !photoDataList.contains(data) {
                        photoDataList.append(data)
                    }
                }
            }
            internalPhotoItems = []
            isUploadingMedia = false
        }
    }
    
    // --- *** RENAMED *** ---
    private func removeNewPhoto(at index: Int) {
        withAnimation {
            photoDataList.remove(at: index)
        }
    }
    
    // --- *** NEW FUNCTION *** ---
    private func removeExistingPhoto(at index: Int) {
        withAnimation {
            editableMediaURLs.remove(at: index)
        }
    }

    
    private func removeLocation() {
        withAnimation {
            selectedLocationString = nil
        }
    }
    
    // MARK: - Actions
    
    // --- *** HEAVILY MODIFIED FUNCTION *** ---
    private func publishOrUpdatePost() {
        guard let userID = authManager.user?.id, let userName = authManager.user?.name else {
            errorMessage = "Error: Could not find user."
            return
        }
        
        let trimmedContent = content.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // --- *** EDITING LOGIC *** ---
        if isEditing, let postToEdit = postToEdit, let postID = postToEdit.id {
            
            // Check if there is anything to post
            if trimmedContent.isEmpty && photoDataList.isEmpty && editableMediaURLs.isEmpty {
                errorMessage = "Your post cannot be empty."
                return
            }
            
            isLoading = true
            errorMessage = nil
            
            Task {
                do {
                    var newlyUploadedURLs: [String] = []
                    
                    // 1. Upload any *new* photos
                    if !photoDataList.isEmpty {
                        isUploadingMedia = true
                        for photoData in photoDataList {
                            let url = try await StorageManager.shared.uploadPostMedia(
                                photoData: photoData,
                                userID: userID
                            )
                            newlyUploadedURLs.append(url)
                        }
                        isUploadingMedia = false
                    }
                    
                    // 2. Combine with remaining *existing* photos
                    let finalMediaURLs = editableMediaURLs + newlyUploadedURLs
                    
                    // 3. Call the updated manager function
                    try await communityManager.updatePostDetails(
                        postID: postID,
                        content: trimmedContent.isEmpty ? nil : trimmedContent,
                        location: selectedLocationString,
                        visibility: visibility,
                        newMediaURLs: finalMediaURLs.isEmpty ? nil : finalMediaURLs // Pass the combined list
                    )
                    
                    // 4. Call the onPostSaved closure to update the UI instantly
                    onPostSaved?(trimmedContent, selectedLocationString, visibility, finalMediaURLs.isEmpty ? nil : finalMediaURLs)
                    dismiss()
                    
                } catch {
                    errorMessage = "Failed to update post: \(error.localizedDescription)"
                    isLoading = false
                    isUploadingMedia = false
                }
            }
            
        // --- *** CREATING LOGIC (Unchanged from before) *** ---
        } else {
            if trimmedContent.isEmpty && photoDataList.isEmpty {
                errorMessage = "Please write something or select a photo to post."
                return
            }
            
            isLoading = true
            errorMessage = nil
            
            Task {
                do {
                    var finalMediaURLs: [String] = []
                    
                    if !photoDataList.isEmpty {
                        isUploadingMedia = true
                        print("Photo data found, attempting to upload \(photoDataList.count) photos...")
                        
                        for photoData in photoDataList {
                            let url = try await StorageManager.shared.uploadPostMedia(
                                photoData: photoData,
                                userID: userID
                            )
                            finalMediaURLs.append(url)
                        }
                        isUploadingMedia = false
                    }
                    
                    let finalPostType: PostType = (finalMediaURLs.isEmpty) ? .text : .photoVideo

                    let newPost = Post(
                        authorID: userID,
                        authorName: userName,
                        authorRole: authManager.role,
                        authorPhotoURL: authManager.user?.photoURL,
                        timestamp: Date(),
                        content: trimmedContent.isEmpty ? nil : trimmedContent,
                        mediaURLs: finalMediaURLs.isEmpty ? nil : finalMediaURLs,
                        location: selectedLocationString,
                        postType: finalPostType,
                        visibility: visibility,
                        isEdited: false // New posts are not edited
                    )
                    
                    try await communityManager.createPost(post: newPost)
                    
                    onPostCreated?()
                    dismiss()
                    
                } catch {
                    errorMessage = "Failed to publish post: \(error.localizedDescription)"
                    isLoading = false
                    isUploadingMedia = false
                }
            }
        }
    }
}
