// File: arafatrahman/myinstructor/MyInstructor-main/MyInstructor/Features/Community/CreatePostView.swift
// --- UPDATED: Fixes Firestore Permission Denied error and uses Sheet for Students ---

import SwiftUI
import PhotosUI
import FirebaseFirestore

struct StudentSelectionItem: Identifiable, Hashable {
    let id: String
    let name: String
    let photoURL: String?
}

// Flow Item 19: Create Post
struct CreatePostView: View {
    @EnvironmentObject var authManager: AuthManager
    @EnvironmentObject var communityManager: CommunityManager
    @EnvironmentObject var dataService: DataService
    @Environment(\.dismiss) var dismiss
    
    let postToEdit: Post?
    var onPostCreated: (() -> Void)? = nil // For creating
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
    
    // --- NEW: Student Selection State ---
    @State private var availableStudents: [StudentSelectionItem] = []
    @State private var selectedStudentIDs: Set<String> = []
    @State private var isFetchingStudents = false
    @State private var isShowingStudentSelection = false // Controls the new sheet
    
    // --- NEW: Privacy Options ---
    var visibilityOptions: [PostVisibility] {
        [.public, .students, .selectedStudents, .private]
    }
    
    init(postToEdit: Post? = nil, initialPhotoData: [Data] = [], onPostCreated: (() -> Void)? = nil, onPostSaved: ((String, String?, PostVisibility, [String]?) -> Void)? = nil) {
        self.postToEdit = postToEdit
        self.onPostCreated = onPostCreated
        self.onPostSaved = onPostSaved
        
        if let post = postToEdit {
            // Editing
            self._content = State(initialValue: post.content ?? "")
            self._visibility = State(initialValue: post.visibility)
            self._selectedLocationString = State(initialValue: post.location)
            self._isEditing = State(initialValue: true)
            self._editableMediaURLs = State(initialValue: post.mediaURLs ?? [])
            self._photoDataList = State(initialValue: [])
            
            // Populate selected students if existing
            if let targets = post.targetStudentIDs {
                self._selectedStudentIDs = State(initialValue: Set(targets))
            }
        } else {
            // Creating
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
                        
                        // 2. Horizontal Scrolling Preview (Existing Photos)
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

                        // 3. Horizontal Scrolling Preview (New Photos)
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

                        // 4. Selected Location
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
                        
                        // 5. Action Icons
                        HStack(spacing: 25) {
                            PhotosPicker(
                                selection: $internalPhotoItems,
                                maxSelectionCount: 5 - (photoDataList.count + editableMediaURLs.count),
                                matching: .images,
                                photoLibrary: .shared()
                            ) {
                                Image(systemName: "photo.on.rectangle.angled")
                                    .font(.title2)
                                    .foregroundColor(.accentGreen)
                                    .contentShape(Rectangle())
                            }
                            .disabled((photoDataList.count + editableMediaURLs.count) >= 5)
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
                
                // MARK: - Privacy & Settings
                Section("Privacy & Settings") {
                    Picker("Who can see this?", selection: $visibility) {
                        Text("Public").tag(PostVisibility.public)
                        Text("All My Students").tag(PostVisibility.students)
                        Text("Selected Students").tag(PostVisibility.selectedStudents)
                        Text("Private (Only Me)").tag(PostVisibility.private)
                    }
                    .pickerStyle(.menu)
                    
                    // --- UPDATED: Professional Student Selection ---
                    if visibility == .selectedStudents {
                        if isFetchingStudents {
                            HStack {
                                Text("Loading students...")
                                    .foregroundColor(.secondary)
                                Spacer()
                                ProgressView()
                            }
                        } else if availableStudents.isEmpty {
                            Text("No students found linked to your account.")
                                .font(.caption).foregroundColor(.gray)
                        } else {
                            Button {
                                isShowingStudentSelection = true
                            } label: {
                                HStack {
                                    Text("Choose Students")
                                        .foregroundColor(.primary)
                                    Spacer()
                                    if selectedStudentIDs.isEmpty {
                                        Text("None")
                                            .foregroundColor(.secondary)
                                    } else {
                                        Text("\(selectedStudentIDs.count) Selected")
                                            .foregroundColor(.primaryBlue)
                                            .bold()
                                    }
                                    Image(systemName: "chevron.right")
                                        .font(.caption)
                                        .foregroundColor(.gray)
                                }
                            }
                        }
                    }
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
                    .disabled(isLoading || isUploadingMedia)
                }
            }
            .sheet(isPresented: $isShowingAddressSearch) {
                AddressSearchView { selectedAddressString in
                    self.selectedLocationString = selectedAddressString
                }
            }
            .sheet(isPresented: $isShowingStudentSelection) {
                StudentSelectorView(
                    selectedStudentIDs: $selectedStudentIDs,
                    students: availableStudents
                )
            }
            // Fetch students if selecting specific visibility
            .task(id: visibility) {
                if visibility == .selectedStudents && availableStudents.isEmpty {
                    await fetchStudents()
                }
            }
            .animation(.default, value: photoDataList)
            .animation(.default, value: editableMediaURLs)
            .animation(.default, value: selectedLocationString)
            .animation(.default, value: visibility)
        }
    }
    
    // MARK: - Helper Functions
    
    private func fetchStudents() async {
        guard let instructorID = authManager.user?.id else { return }
        isFetchingStudents = true
        do {
            async let onlineDocs = dataService.fetchStudents(for: instructorID)
            async let offlineDocs = dataService.fetchOfflineStudents(for: instructorID)
            
            let online = try await onlineDocs
            let offline = try await offlineDocs
            
            let items1 = online.map { StudentSelectionItem(id: $0.userID, name: $0.name, photoURL: $0.photoURL) }
            let items2 = offline.map { StudentSelectionItem(id: $0.id ?? "", name: $0.name, photoURL: nil) }
            
            self.availableStudents = (items1 + items2).sorted(by: { $0.name < $1.name })
            
        } catch {
            print("Error fetching students for post selection: \(error)")
        }
        isFetchingStudents = false
    }
    
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
    
    private func removeNewPhoto(at index: Int) {
        withAnimation {
            photoDataList.remove(at: index)
        }
    }
    
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
    
    private func publishOrUpdatePost() {
        guard let userID = authManager.user?.id, let userName = authManager.user?.name else {
            errorMessage = "Error: Could not find user."
            return
        }
        
        let trimmedContent = content.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Check selection validation
        if visibility == .selectedStudents && selectedStudentIDs.isEmpty {
            errorMessage = "Please select at least one student."
            return
        }
        
        // --- EDITING LOGIC ---
        if isEditing, let postToEdit = postToEdit, let postID = postToEdit.id {
            
            if trimmedContent.isEmpty && photoDataList.isEmpty && editableMediaURLs.isEmpty {
                errorMessage = "Your post cannot be empty."
                return
            }
            
            isLoading = true
            errorMessage = nil
            
            Task {
                do {
                    var newlyUploadedURLs: [String] = []
                    
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
                    
                    let finalMediaURLs = editableMediaURLs + newlyUploadedURLs
                    let finalTargetIDs = visibility == .selectedStudents ? Array(selectedStudentIDs) : nil
                    
                    // --- UPDATED: Call Manager directly with all data ---
                    try await communityManager.updatePostDetails(
                        postID: postID,
                        content: trimmedContent.isEmpty ? nil : trimmedContent,
                        location: selectedLocationString,
                        visibility: visibility,
                        newMediaURLs: finalMediaURLs.isEmpty ? nil : finalMediaURLs,
                        targetStudentIDs: finalTargetIDs
                    )

                    onPostSaved?(trimmedContent, selectedLocationString, visibility, finalMediaURLs.isEmpty ? nil : finalMediaURLs)
                    dismiss()
                    
                } catch {
                    errorMessage = "Failed to update post: \(error.localizedDescription)"
                    isLoading = false
                    isUploadingMedia = false
                }
            }
            
        // --- CREATING LOGIC ---
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
                    let finalTargetIDs = visibility == .selectedStudents ? Array(selectedStudentIDs) : nil

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
                        targetStudentIDs: finalTargetIDs,
                        isEdited: false
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

// MARK: - Student Selection Sheet
struct StudentSelectorView: View {
    @Binding var selectedStudentIDs: Set<String>
    let students: [StudentSelectionItem]
    @Environment(\.dismiss) var dismiss
    
    @State private var searchText = ""
    
    var filteredStudents: [StudentSelectionItem] {
        if searchText.isEmpty { return students }
        return students.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                if students.isEmpty {
                    Text("No students available")
                        .foregroundColor(.gray)
                } else {
                    List {
                        ForEach(filteredStudents) { student in
                            Button {
                                toggleSelection(for: student.id)
                            } label: {
                                HStack(spacing: 12) {
                                    // Avatar
                                    AsyncImage(url: URL(string: student.photoURL ?? "")) { phase in
                                        if let image = phase.image {
                                            image.resizable().scaledToFill()
                                        } else {
                                            ZStack {
                                                Color.gray.opacity(0.2)
                                                Image(systemName: "person.fill")
                                                    .foregroundColor(.gray)
                                            }
                                        }
                                    }
                                    .frame(width: 44, height: 44)
                                    .clipShape(Circle())
                                    
                                    Text(student.name)
                                        .font(.body)
                                        .foregroundColor(.primary)
                                    
                                    Spacer()
                                    
                                    if selectedStudentIDs.contains(student.id) {
                                        Image(systemName: "checkmark.circle.fill")
                                            .font(.title3)
                                            .foregroundColor(.primaryBlue)
                                    } else {
                                        Image(systemName: "circle")
                                            .font(.title3)
                                            .foregroundColor(Color(.systemGray4))
                                    }
                                }
                                .padding(.vertical, 4)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .listStyle(.plain)
                    .searchable(text: $searchText, placement: .navigationBarDrawer(displayMode: .always), prompt: "Search students")
                }
            }
            .navigationTitle("Select Students")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(selectedStudentIDs.count == students.count ? "Deselect All" : "Select All") {
                        if selectedStudentIDs.count == students.count {
                            selectedStudentIDs.removeAll()
                        } else {
                            selectedStudentIDs = Set(students.map { $0.id })
                        }
                    }
                    .font(.subheadline)
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                        .bold()
                }
            }
        }
    }
    
    private func toggleSelection(for id: String) {
        if selectedStudentIDs.contains(id) {
            selectedStudentIDs.remove(id)
        } else {
            selectedStudentIDs.insert(id)
        }
    }
}
