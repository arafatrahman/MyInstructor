// File: arafatrahman/myinstructor/MyInstructor-main/MyInstructor/Features/Community/CreatePostView.swift
// --- UPDATED: Fixed button tap area bug ---

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
    
    // --- STATE FOR NEW FEATURES ---
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var selectedPhotoData: Data?
    @State private var isUploadingMedia = false
    
    @State private var isShowingAddressSearch = false
    @State private var selectedLocationString: String? = nil
    
    var visibilityOptions: [PostVisibility] {
        authManager.role == .instructor ? [.public, .instructors, .students, .private] : [.public, .private]
    }

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
                        
                        // 2. Small Preview (if photo is selected)
                        if let photoData = selectedPhotoData, let uiImage = UIImage(data: photoData) {
                            ZStack(alignment: .topTrailing) {
                                Image(uiImage: uiImage)
                                    .resizable()
                                    .scaledToFit()
                                    .frame(maxHeight: 200)
                                    .cornerRadius(10)
                                    .padding(.top, 10)

                                // Remove Button
                                Button(action: removePhoto) {
                                    Image(systemName: "xmark.circle.fill")
                                        .font(.title2)
                                        .foregroundColor(.white)
                                        .background(Color.black.opacity(0.6).clipShape(Circle()))
                                        .shadow(radius: 2)
                                }
                                .buttonStyle(.plain) // Ensure this button is also plain
                                .padding(15)
                            }
                        }

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
                                .buttonStyle(.plain) // Ensure this button is plain
                            }
                            .padding(8)
                            .background(Color.secondaryGray.opacity(0.5))
                            .cornerRadius(10)
                            .padding(.top, 10)
                        }

                        Divider().padding(.top, 10)
                        
                        // --- *** THIS IS THE CORRECTED HSTACK *** ---
                        // 4. Action Icons
                        HStack(spacing: 25) {
                            // PhotosPicker Icon
                            PhotosPicker(
                                selection: $selectedPhotoItem,
                                matching: .images,
                                photoLibrary: .shared()
                            ) {
                                Image(systemName: "photo.on.rectangle.angled")
                                    .font(.title2)
                                    .foregroundColor(.accentGreen)
                                    .contentShape(Rectangle()) // Define precise tap area
                            }
                            .onChange(of: selectedPhotoItem, handlePhotoSelection)
                            
                            // Location Icon Button
                            Button(action: { isShowingAddressSearch = true }) {
                                Image(systemName: "mappin.and.ellipse")
                                    .font(.title2)
                                    .foregroundColor(.primaryBlue)
                                    .contentShape(Rectangle()) // Define precise tap area
                            }
                            .buttonStyle(.plain) // <-- THIS IS THE FIX
                            
                            Spacer()
                            
                            if isUploadingMedia { ProgressView() }
                        }
                        .padding(.top, 10)
                        // --- *** END OF CORRECTION *** ---
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
                // Present the Address Search View you already created
                AddressSearchView { selectedAddressString in
                    self.selectedLocationString = selectedAddressString
                }
            }
            .animation(.default, value: selectedPhotoData)
            .animation(.default, value: selectedLocationString)
        }
    }
    
    // MARK: - Helper Functions
    
    private func handlePhotoSelection(oldItem: PhotosPickerItem?, newItem: PhotosPickerItem?) {
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
    
    private func removePhoto() {
        withAnimation {
            selectedPhotoItem = nil
            selectedPhotoData = nil
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
        if trimmedContent.isEmpty && selectedPhotoData == nil {
            errorMessage = "Please write something or select a photo to post."
            return
        }
        
        isLoading = true
        errorMessage = nil
        
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
                let finalPostType: PostType = (finalMediaURL != nil) ? .photoVideo : .text

                // 3. Create the Post object
                let newPost = Post(
                    authorID: userID,
                    authorName: userName,
                    authorRole: authManager.role,
                    timestamp: Date(),
                    content: trimmedContent.isEmpty ? nil : trimmedContent,
                    mediaURL: finalMediaURL,
                    location: selectedLocationString, // --- ADDED LOCATION ---
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
