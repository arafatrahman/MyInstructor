// File: arafatrahman/myinstructor/MyInstructor-main/MyInstructor/Features/Community/CreatePostView.swift
// --- UPDATED: Accepts initial photos from the feed view ---

import SwiftUI
import PhotosUI

// Flow Item 19: Create Post
struct CreatePostView: View {
    @EnvironmentObject var authManager: AuthManager
    @EnvironmentObject var communityManager: CommunityManager
    @Environment(\.dismiss) var dismiss
    
    // --- STATE FOR PHOTOS ---
    @State private var internalPhotoItems: [PhotosPickerItem] = [] // For the *internal* picker
    @State private var photoDataList: [Data] // This now holds all photos
    
    // --- OTHER STATE ---
    @State private var content: String = ""
    @State private var visibility: PostVisibility = .public
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var isUploadingMedia = false // For internal picker
    @State private var isShowingAddressSearch = false
    @State private var selectedLocationString: String? = nil
    
    var onPostCreated: () -> Void
    
    var visibilityOptions: [PostVisibility] {
        [.public, .private]
    }
    
    // --- *** NEW INITIALIZER *** ---
    // Accepts photo data from the previous view
    init(initialPhotoData: [Data] = [], onPostCreated: @escaping () -> Void) {
        self.onPostCreated = onPostCreated
        // Use the initial data to set the *initial value* of the @State variable
        self._photoDataList = State(initialValue: initialPhotoData)
    }
    // --- *** END OF UPDATE *** ---

    var body: some View {
        NavigationView {
            Form {
                
                Section("What's on your mind?") {
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
                        // This now iterates over photoDataList
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

                                                // Remove Button
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
                            // --- *** INTERNAL PHOTOS PICKER (for adding MORE) *** ---
                            PhotosPicker(
                                selection: $internalPhotoItems,
                                maxSelectionCount: 5 - photoDataList.count, // Only allow adding up to 5
                                matching: .images,
                                photoLibrary: .shared()
                            ) {
                                Image(systemName: "photo.on.rectangle.angled")
                                    .font(.title2)
                                    .foregroundColor(.accentGreen)
                                    .contentShape(Rectangle())
                            }
                            .disabled(photoDataList.count >= 5) // Disable if 5 photos are already added
                            .onChange(of: internalPhotoItems, handleInternalPhotoSelection)
                            
                            // Location Icon Button
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
                
                // Settings
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
            .navigationTitle("Create Post")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button { publishPost() } label: {
                        if isLoading {
                            ProgressView()
                        } else {
                            Text("Publish").bold()
                        }
                    }
                    .disabled(isLoading || isUploadingMedia)
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
    
    // --- *** NEW HANDLER for the *internal* picker *** ---
    private func handleInternalPhotoSelection(oldItems: [PhotosPickerItem]?, newItems: [PhotosPickerItem]) {
         Task {
            isUploadingMedia = true
            errorMessage = nil
            
            // This loop *appends* new photos to the existing list
            for item in newItems {
                if let data = try? await item.loadTransferable(type: Data.self) {
                    // Add photo if not already in the list
                    if !photoDataList.contains(data) {
                        photoDataList.append(data)
                    }
                }
            }
            // Clear the picker's selection
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
    
    private func publishPost() {
        guard let userID = authManager.user?.id, let userName = authManager.user?.name else {
            errorMessage = "Error: Could not find user."
            return
        }
        
        let trimmedContent = content.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmedContent.isEmpty && photoDataList.isEmpty { // --- Use photoDataList
            errorMessage = "Please write something or select a photo to post."
            return
        }
        
        isLoading = true
        errorMessage = nil
        
        Task {
            do {
                var finalMediaURLs: [String] = []
                
                // 1. If photo data exists, upload it IN A LOOP
                if !photoDataList.isEmpty { // --- Use photoDataList
                    print("Photo data found, attempting to upload \(photoDataList.count) photos...")
                    
                    for photoData in photoDataList { // --- Use photoDataList
                        let url = try await StorageManager.shared.uploadPostMedia(
                            photoData: photoData,
                            userID: userID
                        )
                        finalMediaURLs.append(url)
                    }
                }
                
                // 2. Determine PostType implicitly
                let finalPostType: PostType = (finalMediaURLs.isEmpty) ? .text : .photoVideo

                // 3. Create the Post object
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
                
                // 4. Save the Post object to Firestore
                try await communityManager.createPost(post: newPost)
                
                // 5. Success: Call handler and dismiss
                onPostCreated()
                dismiss()
                
            } catch {
                errorMessage = "Failed to publish post: \(error.localizedDescription)"
                isLoading = false
            }
        }
    }
}
