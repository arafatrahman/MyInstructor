// File: arafatrahman/myinstructor/MyInstructor-main/MyInstructor/Features/Community/CommunityFeedView.swift
// --- UPDATED: Implemented Privacy Filtering (Private, Student-Only, Selected-Students) ---

import SwiftUI
import PhotosUI
import FirebaseFirestore

// --- Wrapper to make [Data] Identifiable for the sheet ---
struct PhotoSelection: Identifiable {
    let id = UUID()
    let images: [Data]
}

struct CommunityFeedView: View {
    @EnvironmentObject var communityManager: CommunityManager
    @EnvironmentObject var authManager: AuthManager
    
    @State private var searchText = ""
    @State private var isSearchVisible = false
    @State private var selectedAlgorithm: FeedAlgorithm = .latest
    
    @State private var isCreatePostPresented = false
    @State private var feedPhotoItems: [PhotosPickerItem] = []
    @State private var isProcessingPhotos = false
    
    @State private var loadedDataForSheet: PhotoSelection? = nil
    @State private var isInitialLoading = true
    
    // --- UPDATED: Privacy Filtering Logic ---
    var filteredPosts: [Post] {
        let allPosts = communityManager.posts
        
        // 1. Filter by Privacy Rules
        let privacyFilteredPosts = allPosts.filter { post in
            // Rule 1: Author always sees their own posts
            if let currentUserID = authManager.user?.id, post.authorID == currentUserID {
                return true
            }
            
            switch post.visibility {
            case .public:
                // Visible to everyone
                return true
                
            case .private:
                // Only visible to author (handled above), so hide for everyone else
                return false
                
            case .students:
                // Visible only if the viewer is a student of the author
                // We check if the viewer's 'instructorIDs' list contains the post author's ID
                return authManager.user?.instructorIDs?.contains(post.authorID) ?? false
                
            case .selectedStudents:
                // Visible only if the viewer's ID is specifically in the target list
                return post.targetStudentIDs?.contains(authManager.user?.id ?? "") ?? false
                
            case .instructors:
                // Visible to all instructors (assuming this use case)
                return authManager.role == .instructor
            }
        }
        
        // 2. Filter by Search Text
        if searchText.isEmpty {
            return privacyFilteredPosts
        } else {
            return privacyFilteredPosts.filter {
                ($0.content?.localizedCaseInsensitiveContains(searchText) ?? false) ||
                $0.authorName.localizedCaseInsensitiveContains(searchText)
            }
        }
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                
                // MARK: - 1. Main Header
                HStack {
                    // --- TITLE UPDATED to Broadcast Hub ---
                    Text("Broadcast Hub")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundColor(.primary)
                    
                    Spacer()
                    
                    // Search Button
                    Button {
                        withAnimation {
                            isSearchVisible.toggle()
                            if !isSearchVisible { searchText = "" }
                        }
                    } label: {
                        Image(systemName: isSearchVisible ? "xmark.circle.fill" : "magnifyingglass")
                            .font(.title2)
                            .foregroundColor(.primaryBlue)
                            .padding(8)
                            .background(Color.gray.opacity(0.1))
                            .clipShape(Circle())
                    }
                }
                .padding(.horizontal)
                .padding(.top, 10)
                .padding(.bottom, 10)
                
                // Search Bar
                if isSearchVisible {
                    HStack {
                        Image(systemName: "magnifyingglass").foregroundColor(.gray)
                        TextField("Search broadcasts...", text: $searchText)
                            .textFieldStyle(PlainTextFieldStyle())
                        if !searchText.isEmpty {
                            Button(action: { searchText = "" }) {
                                Image(systemName: "xmark.circle.fill").foregroundColor(.gray)
                            }
                        }
                    }
                    .padding(10)
                    .background(Color(.systemGray6))
                    .cornerRadius(10)
                    .padding(.horizontal)
                    .transition(.move(edge: .top).combined(with: .opacity))
                }
                
                // MARK: - Algorithm Filter Bar
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(FeedAlgorithm.allCases) { algo in
                            Button {
                                selectedAlgorithm = algo
                            } label: {
                                Text(algo.rawValue)
                                    .font(.subheadline).bold()
                                    .padding(.vertical, 6)
                                    .padding(.horizontal, 16)
                                    .background(selectedAlgorithm == algo ? Color.primaryBlue : Color(.systemGray6))
                                    .foregroundColor(selectedAlgorithm == algo ? .white : .primary)
                                    .clipShape(Capsule())
                            }
                        }
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 10)
                }
                .padding(.top, 20)
                
                ScrollView {
                    VStack(spacing: 15) {
                        
                        // MARK: - 2. Create Post Bar
                        HStack(spacing: 12) {
                            AsyncImage(url: URL(string: authManager.user?.photoURL ?? "")) { phase in
                                if let image = phase.image { image.resizable().scaledToFill() }
                                else { Image(systemName: "person.circle.fill").resizable().foregroundColor(Color(.systemGray4)) }
                            }
                            .frame(width: 45, height: 45).clipShape(Circle())
                            
                            Button { isCreatePostPresented = true } label: {
                                Text("What's on your mind?").font(.body).foregroundColor(.gray); Spacer()
                            }.buttonStyle(.plain)
                            
                            PhotosPicker(selection: $feedPhotoItems, maxSelectionCount: 5, matching: .images) {
                                HStack(spacing: 6) {
                                    if isProcessingPhotos { ProgressView().tint(.white) }
                                    else { Image(systemName: "photo.fill").font(.subheadline); Text("Photo").font(.subheadline).bold() }
                                }
                                .padding(.horizontal, 16).padding(.vertical, 8).background(Color.green).foregroundColor(.white).clipShape(Capsule())
                            }
                            .disabled(isProcessingPhotos)
                            .onChange(of: feedPhotoItems) { newItems in
                                guard !newItems.isEmpty else { return }
                                Task {
                                    isProcessingPhotos = true
                                    var loadedData: [Data] = []
                                    for item in newItems {
                                        if let data = try? await item.loadTransferable(type: Data.self) { loadedData.append(data) }
                                    }
                                    self.loadedDataForSheet = PhotoSelection(images: loadedData)
                                    self.feedPhotoItems = []
                                    isProcessingPhotos = false
                                }
                            }
                        }
                        .padding(12).background(Color(.systemGray6)).cornerRadius(35).padding(.horizontal)
                        
                        // MARK: - 3. Feed List
                        if isInitialLoading && communityManager.posts.isEmpty {
                            ProgressView("Loading Broadcasts...").padding(.top, 50)
                        } else if communityManager.posts.isEmpty {
                            EmptyStateView(icon: "message.circle", message: "No broadcasts yet. Start a conversation now!")
                        } else if filteredPosts.isEmpty {
                            EmptyStateView(icon: "magnifyingglass", message: "No broadcasts match your search (or privacy settings).")
                        } else {
                            LazyVStack(spacing: 15) {
                                ForEach(filteredPosts) { post in
                                    // Use the index from the main array to ensure binding works correctly
                                    if let mainIndex = communityManager.posts.firstIndex(where: { $0.id == post.id }) {
                                        PostCard(
                                            post: $communityManager.posts[mainIndex],
                                            onDelete: { _ in }
                                        )
                                    }
                                }
                            }
                            .padding(.horizontal).padding(.bottom, 20)
                        }
                    }
                }
            }
            .navigationBarHidden(true)
            .task {
                communityManager.listenToFeed(algorithm: selectedAlgorithm)
                try? await Task.sleep(nanoseconds: 500_000_000)
                isInitialLoading = false
            }
            .onChange(of: selectedAlgorithm) { newAlgo in
                communityManager.listenToFeed(algorithm: newAlgo)
            }
            .sheet(isPresented: $isCreatePostPresented) {
                CreatePostView(postToEdit: nil, onPostCreated: { isCreatePostPresented = false })
            }
            .sheet(item: $loadedDataForSheet) { selection in
                CreatePostView(initialPhotoData: selection.images, onPostCreated: { loadedDataForSheet = nil })
            }
        }
        .navigationViewStyle(.stack)
    }
}

// MARK: - PostCard Component (Unchanged logic, just context)
struct PostCard: View {
    @Binding var post: Post
    let onDelete: (String) -> Void
    var showCommentsList: Bool = true
    
    @EnvironmentObject var communityManager: CommunityManager
    @EnvironmentObject var authManager: AuthManager

    @State private var currentImagePage = 0
    @State private var isCommenting: Bool = false
    @State private var commentText: String = ""
    @State private var isPostingComment: Bool = false
    
    @State private var fetchedComments: [Comment]? = nil
    @State private var commentsListener: ListenerRegistration?
    
    @State private var expandedReplyIDs: Set<String> = []
    
    @State private var isFollowing = false
    @State private var isShowingEditSheet = false
    @State private var isShowingDeleteAlert = false
    
    @State private var replyingToComment: Comment? = nil
    @State private var editingComment: Comment? = nil
    
    var isMe: Bool {
        post.authorID == authManager.user?.id
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            headerView
            contentView
            mediaView
            
            Divider()
                .background(Color(.systemGray5))
            
            HStack {
                reactionBar
                Spacer()
                Button {
                    withAnimation { isCommenting.toggle() }
                    if isCommenting {
                        startListeningToComments()
                    } else {
                        stopListeningToComments()
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "bubble.left")
                        Text("\(post.commentsCount) Comments")
                    }
                    .font(.caption).foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding(.top, 5)
            
            commentsSection
        }
        .padding(15).background(Color.white).cornerRadius(20)
        .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
        .sheet(isPresented: $isShowingEditSheet) {
            CreatePostView(
                postToEdit: post,
                onPostSaved: { newContent, newLocation, newVisibility, newMediaURLs in
                    isShowingEditSheet = false
                    post.content = newContent.isEmpty ? nil : newContent
                    post.location = newLocation
                    post.visibility = newVisibility
                    post.isEdited = true
                    post.mediaURLs = newMediaURLs
                }
            )
        }
        .alert("Delete Broadcast?", isPresented: $isShowingDeleteAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) { Task { await deletePost() } }
        } message: { Text("Are you sure you want to delete this broadcast?") }
        .task {
            updateFollowingState()
        }
        .onChange(of: authManager.user?.following) { _ in
            updateFollowingState()
        }
        .onDisappear {
            stopListeningToComments()
        }
    }
    
    // MARK: - Subviews
    private var headerView: some View {
        HStack(alignment: .center, spacing: 10) {
            NavigationLink(destination: InstructorPublicProfileView(instructorID: post.authorID)) {
                AsyncImage(url: URL(string: post.authorPhotoURL ?? "")) { phase in
                    if let image = phase.image { image.resizable().scaledToFill() }
                    else { Image(systemName: "person.circle.fill").resizable().foregroundColor(.gray) }
                }
                .frame(width: 45, height: 45).clipShape(Circle())
            }
            
            VStack(alignment: .leading, spacing: 2) {
                NavigationLink(destination: InstructorPublicProfileView(instructorID: post.authorID)) {
                    Text(post.authorName).font(.headline).foregroundColor(.primary)
                }
                HStack(spacing: 4) {
                    Text(post.timestamp.timeAgoDisplay())
                    
                    // --- Privacy Indicator ---
                    if post.visibility == .private {
                        Image(systemName: "lock.fill").font(.caption2).foregroundColor(.secondary)
                    } else if post.visibility == .students {
                        Image(systemName: "person.2.fill").font(.caption2).foregroundColor(.secondary)
                    } else if post.visibility == .selectedStudents {
                        Image(systemName: "person.crop.circle.badge.checkmark").font(.caption2).foregroundColor(.secondary)
                    }
                    
                    if post.isEdited == true { Text("• (edited)") }
                }.font(.caption).foregroundColor(.textLight)
            }
            
            Spacer()
            
            if isMe {
                Menu {
                    Button { isShowingEditSheet = true } label: { Label("Edit Post", systemImage: "pencil") }
                    Button(role: .destructive) { isShowingDeleteAlert = true } label: { Label("Delete Post", systemImage: "trash") }
                } label: {
                    Image(systemName: "ellipsis").font(.headline).foregroundColor(.textLight)
                        .padding(10).background(Color.gray.opacity(0.1)).clipShape(Circle())
                }
            } else {
                Button(action: handleFollowToggle) {
                    Text(isFollowing ? "Unfollow" : "Follow")
                        .font(.caption).bold()
                        .padding(.horizontal, 16)
                        .padding(.vertical, 6)
                        .background(isFollowing ? Color.gray.opacity(0.2) : Color.blue)
                        .foregroundColor(isFollowing ? .primary : .white)
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }
        }
    }
    
    @ViewBuilder
    private var contentView: some View {
        if let content = post.content {
            Text(content).font(.body).foregroundColor(.primary).padding(.top, 4)
        }
    }
    
    @ViewBuilder
    private var mediaView: some View {
        if let mediaURLs = post.mediaURLs, !mediaURLs.isEmpty {
            ZStack(alignment: .topTrailing) {
                TabView(selection: $currentImagePage) {
                    ForEach(Array(mediaURLs.enumerated()), id: \.offset) { index, urlString in
                        AsyncImage(url: URL(string: urlString)) { phase in
                            if let image = phase.image { image.resizable().scaledToFill() }
                            else { ZStack { Color.gray.opacity(0.1); ProgressView() } }
                        }
                        .tag(index).clipped()
                    }
                }
                .frame(height: 300).tabViewStyle(.page(indexDisplayMode: .never)).cornerRadius(12)
                
                if mediaURLs.count > 1 {
                    Text("\(currentImagePage + 1)/\(mediaURLs.count)")
                        .font(.caption.bold()).padding(6).background(Color.black.opacity(0.6)).foregroundColor(.white).cornerRadius(8).padding(10)
                }
            }
        }
    }
    
    private var reactionBar: some View {
        HStack(spacing: 15) {
            ReactionButton(post: $post, reactionType: "thumbsup", icon: "hand.thumbsup.fill", color: .blue)
            ReactionButton(post: $post, reactionType: "fire", icon: "flame.fill", color: .orange)
            ReactionButton(post: $post, reactionType: "heart", icon: "heart.fill", color: .red)
        }
    }
    
    @ViewBuilder
    private var commentsSection: some View {
        if showCommentsList && isCommenting {
            VStack(alignment: .leading, spacing: 10) {
                Divider()
                
                if let replying = replyingToComment {
                    HStack {
                        Text("Replying to \(replying.authorName)").font(.caption).foregroundColor(.secondary)
                        Spacer()
                        Button { replyingToComment = nil; commentText = "" } label: { Image(systemName: "xmark.circle.fill") }.buttonStyle(.plain)
                    }
                }
                if let editing = editingComment {
                    HStack {
                        Text("Editing your comment").font(.caption).foregroundColor(.primaryBlue)
                        Spacer()
                        Button { editingComment = nil; commentText = "" } label: { Image(systemName: "xmark.circle.fill") }.buttonStyle(.plain)
                    }
                }
                
                if fetchedComments == nil {
                    HStack { Spacer(); ProgressView(); Spacer() }
                } else if let comments = fetchedComments, !comments.isEmpty {
                    
                    let parents = comments.filter { $0.parentCommentID == nil }
                    let visibleParents = parents.prefix(3)
                    
                    ForEach(visibleParents) { parent in
                        let isExpanded = expandedReplyIDs.contains(parent.id ?? "")
                        
                        CommentRow(
                            comment: parent,
                            isExpanded: isExpanded,
                            currentUserID: authManager.user?.id,
                            postAuthorID: post.authorID,
                            onReply: {
                                replyingToComment = parent
                                editingComment = nil
                                commentText = "@\(parent.authorName) "
                            },
                            onToggleReplies: {
                                withAnimation {
                                    if isExpanded { expandedReplyIDs.remove(parent.id ?? "") }
                                    else { expandedReplyIDs.insert(parent.id ?? "") }
                                }
                            },
                            onEdit: {
                                editingComment = parent
                                replyingToComment = nil
                                commentText = parent.content
                            },
                            onDelete: {
                                Task { await deleteComment(parent) }
                            }
                        )
                        
                        if isExpanded {
                            let replies = comments.filter { $0.parentCommentID == parent.id }
                            ForEach(replies) { reply in
                                CommentRow(
                                    comment: reply,
                                    isExpanded: false,
                                    currentUserID: authManager.user?.id,
                                    postAuthorID: post.authorID,
                                    onReply: {
                                        replyingToComment = parent
                                        editingComment = nil
                                        commentText = "@\(reply.authorName) "
                                    },
                                    onEdit: {
                                        editingComment = reply
                                        replyingToComment = nil
                                        commentText = reply.content
                                    },
                                    onDelete: {
                                        Task { await deleteComment(reply) }
                                    }
                                )
                                .padding(.leading, 30)
                            }
                        }
                    }
                    
                    if parents.count > 3 {
                        NavigationLink(destination: PostDetailView(post: post)) {
                            Text("View all comments...").font(.caption).foregroundColor(.blue)
                        }
                    }
                } else {
                    Text("No comments yet.").font(.caption).foregroundColor(.gray)
                }
                
                HStack {
                    TextField("Write a comment...", text: $commentText).font(.caption).padding(8).background(Color(.secondarySystemBackground)).cornerRadius(15)
                    Button { Task { await postComment() } } label: { Image(systemName: "paperplane.fill").foregroundColor(.blue) }.disabled(commentText.isEmpty)
                }
            }
        }
    }
    
    private func startListeningToComments() {
        guard let postID = post.id else { return }
        stopListeningToComments()
        commentsListener = communityManager.listenToCommentsForPost(postID: postID) { newComments in
            self.fetchedComments = newComments
        }
    }
    
    private func stopListeningToComments() {
        commentsListener?.remove()
        commentsListener = nil
    }
    
    private func updateFollowingState() {
        if let followers = authManager.user?.following {
            isFollowing = followers.contains(post.authorID)
        } else {
            isFollowing = false
        }
    }
    
    private func handleFollowToggle() {
        Task {
            guard let myID = authManager.user?.id, let name = authManager.user?.name else { return }
            isFollowing.toggle()
            
            if !isFollowing {
                try? await communityManager.unfollowUser(currentUserID: myID, targetUserID: post.authorID)
                if var following = authManager.user?.following {
                    following.removeAll { $0 == post.authorID }
                    authManager.user?.following = following
                }
            } else {
                try? await communityManager.followUser(currentUserID: myID, targetUserID: post.authorID, currentUserName: name)
                if authManager.user?.following == nil { authManager.user?.following = [] }
                authManager.user?.following?.append(post.authorID)
            }
        }
    }
    
    private func deletePost() async {
        guard let postID = post.id else { return }
        try? await communityManager.deletePost(postID: postID)
        await MainActor.run { onDelete(postID) }
    }
    
    private func postComment() async {
        guard let postID = post.id, let author = authManager.user, let authorID = author.id else { return }
        isPostingComment = true
        
        let content = commentText
        
        if let editing = editingComment, let cid = editing.id {
            try? await communityManager.updateComment(postID: postID, commentID: cid, newContent: content)
            editingComment = nil
        } else {
            let parentID = replyingToComment?.id
            try? await communityManager.addComment(postID: postID, authorID: authorID, authorName: author.name ?? "User", authorRole: author.role, authorPhotoURL: author.photoURL, content: content, parentCommentID: parentID)
            replyingToComment = nil
        }
        
        commentText = ""
        isPostingComment = false
    }
    
    private func deleteComment(_ comment: Comment) async {
        guard let postID = post.id, let commentID = comment.id else { return }
        try? await communityManager.deleteComment(postID: postID, commentID: commentID, parentCommentID: comment.parentCommentID)
    }
}

// MARK: - Supporting Views (Unchanged)
struct ReactionButton: View {
    @EnvironmentObject var communityManager: CommunityManager
    @EnvironmentObject var authManager: AuthManager
    @Binding var post: Post
    let reactionType: String
    let icon: String
    let color: Color
    @State private var isDisabled = false
    
    var body: some View {
        Button {
            isDisabled = true
            Task {
                guard let postID = post.id, let user = authManager.user else { isDisabled = false; return }
                try? await communityManager.addReaction(postID: postID, user: user, reactionType: reactionType)
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { isDisabled = false }
            }
        } label: {
            HStack(spacing: 4) {
                Image(systemName: icon).foregroundColor(color)
                if let count = post.reactionsCount[reactionType], count > 0 { Text("\(count)").font(.caption).bold().foregroundColor(.secondary) }
            }
        }
        .buttonStyle(.plain).disabled(isDisabled)
    }
}

extension Date {
    func timeAgoDisplay() -> String {
        let secondsAgo = Int(Date().timeIntervalSince(self))
        if secondsAgo < 60 { return "Just now" }
        let minutes = secondsAgo / 60
        if minutes < 60 { return "\(minutes)m ago" }
        let hours = minutes / 60
        if hours < 24 { return "\(hours)h ago" }
        let days = hours / 24
        if days < 7 { return "\(days)d ago" }
        let weeks = days / 7
        if weeks < 4 { return "\(weeks)w ago" }
        let months = days / 30
        if months < 12 { return "\(months)mo ago" }
        let years = months / 12
        return "\(years)y ago"
    }
}
