// File: arafatrahman/myinstructor/MyInstructor-main/MyInstructor/Features/Community/CreatePostView.swift
// --- UPDATED: Handles multiple photos and simplified visibility ---

import SwiftUI
import PhotosUI

// Flow Item 19: Create Post
struct CreatePostView: View {
    @EnvironmentObject var authManager: AuthManager
    @EnvironmentObject var communityManager: CommunityManager
    @Environment(\.dismiss) var dismiss
    
    var onPostCreated: () -> Void

    @State private var content: String = ""
    @State private var visibility: PostVisibility = .public
    
    @State private var isLoading = false
    @State private var errorMessage: String?
    
    // --- STATE FOR MULTIPLE PHOTOS ---
    @State private var selectedPhotoItems: [PhotosPickerItem] = []
    @State private var selectedPhotoData: [Data] = []
    @State private var isUploadingMedia = false
    
    @State private var isShowingAddressSearch = false
    @State private var selectedLocationString: String? = nil
    
    // --- *** THIS IS THE UPDATED VISIBILITY *** ---
    var visibilityOptions: [PostVisibility] {
        [.public, .private]
    }
    // --- *** END OF UPDATE *** ---

    var body: some View {
        NavigationView {
            Form {
                
                // --- THIS SECTION IS THE NEW DESIGN ---
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
                        
                        // --- *** UPDATED PHOTO PREVIEW LOOP *** ---
                        // 2. Horizontal Scrolling Preview (if photos are selected)
                        if !selectedPhotoData.isEmpty {
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 8) {
                                    ForEach(Array(selectedPhotoData.enumerated()), id: \.offset) { index, photoData in
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
                                                        .font(.callout) // Smaller icon
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
                            .frame(height: 110) // Set a fixed height for the scroll view
                        }
                        // --- *** END OF PREVIEW LOOP *** ---

                        // 3. Selected Location (if selected)
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
                            // --- *** UPDATED PHOTOSPICKER *** ---
                            // PhotosPicker Icon for MULTIPLE items
                            PhotosPicker(
                                selection: $selectedPhotoItems, // Binds to the array
                                maxSelectionCount: 5, // Set a limit
                                matching: .images,
                                photoLibrary: .shared()
                            ) {
                                Image(systemName: "photo.on.rectangle.angled")
                                    .font(.title2)
                                    .foregroundColor(.accentGreen)
                                    .contentShape(Rectangle())
                            }
                            .onChange(of: selectedPhotoItems, handlePhotoSelection)
                            // --- *** END OF UPDATE *** ---
                            
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
                    // --- *** UPDATED VISIBILITY PICKER *** ---
                    Picker("Visibility", selection: $visibility) {
                        ForEach(visibilityOptions, id: \.self) { option in
                            // Use icons for a cleaner look
                            if option == .public {
                                Label("Public", systemImage: "globe").tag(PostVisibility.public)
                            } else if option == .private {
                                Label("Private", systemImage: "lock.fill").tag(PostVisibility.private)
                            }
                        }
                    }
                    .pickerStyle(.segmented) // Segmented style looks good for two options
                    // --- *** END OF UPDATE *** ---
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
            .animation(.default, value: selectedPhotoData)
            .animation(.default, value: selectedLocationString)
        }
    }
    
    // MARK: - Helper Functions
    
    // --- *** UPDATED HANDLER FOR MULTIPLE PHOTOS *** ---
    private func handlePhotoSelection(oldItems: [PhotosPickerItem]?, newItems: [PhotosPickerItem]) {
         Task {
            isUploadingMedia = true
            errorMessage = nil
            
            // This reloads all items in the selection.
            var newData: [Data] = []
            for item in newItems {
                if let data = try? await item.loadTransferable(type: Data.self) {
                    newData.append(data)
                }
            }
            // This ensures the data array matches the items array
            selectedPhotoData = newData
            
            isUploadingMedia = false
        }
    }
    
    // --- *** UPDATED REMOVE FUNCTION *** ---
    private func removePhoto(at index: Int) {
        withAnimation {
            // Remove from both arrays to keep them in sync
            selectedPhotoData.remove(at: index)
            selectedPhotoItems.remove(at: index)
        }
    }
    
    private func removeLocation() {
        withAnimation {
            selectedLocationString = nil
        }
    }
    
    // MARK: - Actions
    
    // --- *** UPDATED PUBLISH FUNCTION *** ---
    private func publishPost() {
        guard let userID = authManager.user?.id, let userName = authManager.user?.name else {
            errorMessage = "Error: Could not find user."
            return
        }
        
        let trimmedContent = content.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmedContent.isEmpty && selectedPhotoData.isEmpty {
            errorMessage = "Please write something or select a photo to post."
            return
        }
        
        isLoading = true
        errorMessage = nil
        
        Task {
            do {
                var finalMediaURLs: [String] = []
                
                // 1. If photo data exists, upload it IN A LOOP
                if !selectedPhotoData.isEmpty {
                    print("Photo data found, attempting to upload \(selectedPhotoData.count) photos...")
                    
                    for photoData in selectedPhotoData {
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
                    timestamp: Date(),
                    content: trimmedContent.isEmpty ? nil : trimmedContent,
                    mediaURLs: finalMediaURLs.isEmpty ? nil : finalMediaURLs, // Save the array
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
