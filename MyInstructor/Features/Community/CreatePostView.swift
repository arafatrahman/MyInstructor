// File: arafatrahman/myinstructor/MyInstructor-main/MyInstructor/Features/Community/CreatePostView.swift
// --- UPDATED: Now supports two separate closures for Create vs. Edit ---

import SwiftUI
import PhotosUI

// Flow Item 19: Create Post
struct CreatePostView: View {
    @EnvironmentObject var authManager: AuthManager
    @EnvironmentObject var communityManager: CommunityManager
    @Environment(\.dismiss) var dismiss
    
    // --- *** MODIFIED: Split closures ---
    let postToEdit: Post?
    var onPostCreated: (() -> Void)? = nil // For creating
    var onPostSaved: ((String, String?, PostVisibility) -> Void)? = nil // For editing
    // --- *** ---
    
    // --- STATE FOR PHOTOS ---
    @State private var internalPhotoItems: [PhotosPickerItem] = []
    @State private var photoDataList: [Data]
    
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
    init(postToEdit: Post? = nil, initialPhotoData: [Data] = [], onPostCreated: (() -> Void)? = nil, onPostSaved: ((String, String?, PostVisibility) -> Void)? = nil) {
        self.postToEdit = postToEdit
        self.onPostCreated = onPostCreated // <-- MODIFIED
        self.onPostSaved = onPostSaved     // <-- MODIFIED
        
        if let post = postToEdit {
            self._content = State(initialValue: post.content ?? "")
            self._visibility = State(initialValue: post.visibility)
            self._selectedLocationString = State(initialValue: post.location)
            self._isEditing = State(initialValue: true)
            self._photoDataList = State(initialValue: [])
        } else {
            self._content = State(initialValue: "")
            self._visibility = State(initialValue: .public)
            self._selectedLocationString = State(initialValue: nil)
            self._isEditing = State(initialValue: false)
            self._photoDataList = State(initialValue: initialPhotoData)
        }
    }
    // --- *** END OF UPDATE *** ---

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
                        if isEditing, let mediaURLs = postToEdit?.mediaURLs, !mediaURLs.isEmpty {
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 8) {
                                    ForEach(mediaURLs, id: \.self) { urlString in
                                        AsyncImage(url: URL(string: urlString)) { phase in
                                            if let image = phase.image {
                                                image.resizable().scaledToFill()
                                            } else {
                                                ProgressView()
                                            }
                                        }
                                        .frame(width: 100, height: 100)
                                        .cornerRadius(10)
                                    }
                                }
                                .padding(.top, 10)
                            }
                            .frame(height: 110)
                            .overlay(
                                Text("Photo editing is not supported.")
                                    .font(.caption)
                                    .foregroundColor(.white)
                                    .padding(5)
                                    .background(Color.black.opacity(0.5))
                                    .cornerRadius(5)
                            )
                        
                        } else if !photoDataList.isEmpty {
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

                                                Button(action: { removePhoto(at: index) }) {
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
                            PhotosPicker(
                                selection: $internalPhotoItems,
                                maxSelectionCount: 5 - photoDataList.count,
                                matching: .images,
                                photoLibrary: .shared()
                            ) {
                                Image(systemName: "photo.on.rectangle.angled")
                                    .font(.title2)
                                    .foregroundColor(isEditing ? .gray : .accentGreen)
                                    .contentShape(Rectangle())
                            }
                            .disabled(isEditing || photoDataList.count >= 5)
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
                    .disabled(isLoading || (isUploadingMedia && !isEditing))
                }
            }
            .sheet(isPresented: $isShowingAddressSearch) {
                AddressSearchView { selectedAddressString in
                    self.selectedLocationString = selectedAddressString
                }
            }
            .animation(.default, value: photoDataList)
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
    
    private func removePhoto(at index: Int) {
        withAnimation {
            photoDataList.remove(at: index)
        }
    }
    
    private func removeLocation() {
        withAnimation {
            selectedLocationString = nil
        }
    }
    
    // MARK: - Actions
    
    private func publishOrUpdatePost() {
        guard let userID = authManager.user?.id, let userName = authManager.user?.name else {
            errorMessage = "Error: Could not find user."
            return
        }
        
        let trimmedContent = content.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // --- *** EDITING LOGIC *** ---
        if isEditing, let postToEdit = postToEdit, let postID = postToEdit.id {
            isLoading = true
            errorMessage = nil
            
            Task {
                do {
                    try await communityManager.updatePostDetails(
                        postID: postID,
                        content: trimmedContent.isEmpty ? nil : trimmedContent,
                        location: selectedLocationString,
                        visibility: visibility
                    )
                    
                    // --- *** MODIFIED: Call onPostSaved *** ---
                    // This instantly updates the @Binding in the feed
                    onPostSaved?(trimmedContent, selectedLocationString, visibility)
                    dismiss()
                    
                } catch {
                    errorMessage = "Failed to update post: \(error.localizedDescription)"
                    isLoading = false
                }
            }
            
        // --- *** CREATING LOGIC *** ---
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
                        print("Photo data found, attempting to upload \(photoDataList.count) photos...")
                        
                        for photoData in photoDataList {
                            let url = try await StorageManager.shared.uploadPostMedia(
                                photoData: photoData,
                                userID: userID
                            )
                            finalMediaURLs.append(url)
                        }
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
                        visibility: visibility
                    )
                    
                    try await communityManager.createPost(post: newPost)
                    
                    // --- *** MODIFIED: Call onPostCreated *** ---
                    // This tells the feed to refresh its list
                    onPostCreated?()
                    dismiss()
                    
                } catch {
                    errorMessage = "Failed to publish post: \(error.localizedDescription)"
                    isLoading = false
                }
            }
        }
    }
}
