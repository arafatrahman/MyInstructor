// File: arafatrahman/myinstructor/MyInstructor-main/MyInstructor/Features/Community/CommunityFeedView.swift
// --- UPDATED: Added init to FeedCommentRow to fix "Missing argument" error ---

import SwiftUI
import PhotosUI

// Flow Item 18: Community Feed
struct CommunityFeedView: View {
    @EnvironmentObject var communityManager: CommunityManager
    @EnvironmentObject var authManager: AuthManager
    
    @State private var posts: [Post] = []
    @State private var searchText = ""
    @State private var filterMode: CommunityFilter = .all
    
    @State private var isCreatePostPresented = false
    @State private var feedPhotoItems: [PhotosPickerItem] = []
    @State private var isProcessingPhotos = false
    @State private var loadedDataForSheet: [Data]? = nil
    
    @State private var isLoading = true
    
    var filteredPosts: [Post] {
        if searchText.isEmpty {
            return posts
        } else {
            return posts.filter { $0.content?.localizedCaseInsensitiveContains(searchText) ?? false || $0.authorName.localizedCaseInsensitiveContains(searchText) }
        }
    }
    
    private var postIndices: [Int] {
        if searchText.isEmpty {
            return Array(posts.indices)
        } else {
            return posts.indices.filter { index in
                let post = posts[index]
                return post.content?.localizedCaseInsensitiveContains(searchText) ?? false || post.authorName.localizedCaseInsensitiveContains(searchText)
            }
        }
    }

    var body: some View {
        NavigationView {
            VStack(spacing: 15) {
                
                // --- CUSTOM HEADER ---
                HStack {
                    Text("Community Hub")
                        .font(.largeTitle).bold()
                        .foregroundColor(.textDark)
                    
                    Spacer()
                    
                    Button {
                        print("Search tapped")
                    } label: {
                        Image(systemName: "magnifyingglass")
                            .font(.title2)
                            .foregroundColor(.textDark)
                    }
                    .padding(.trailing, 5)
                    
                    if authManager.role == .student {
                        NavigationLink(destination: InstructorDirectoryView()) {
                            Image(systemName: "person.badge.plus.fill")
                                .font(.title2)
                                .foregroundColor(.primaryBlue)
                        }
                    }
                }
                .padding(.horizontal)
                .padding(.top, 10)
                
                // --- "CREATE POST" BAR ---
                HStack(spacing: 10) {
                    AsyncImage(url: URL(string: authManager.user?.photoURL ?? "")) { phase in
                        if let image = phase.image {
                            image.resizable().scaledToFill()
                        } else {
                            Image(systemName: "person.circle.fill")
                                .resizable().foregroundColor(.secondaryGray)
                        }
                    }
                    .frame(width: 40, height: 40)
                    .clipShape(Circle())
                    .background(Color.secondaryGray.clipShape(Circle()))
                    
                    Button {
                        isCreatePostPresented = true
                    } label: {
                        HStack {
                            Text("What's on your mind?")
                                .font(.subheadline)
                                .foregroundColor(.textLight)
                            Spacer()
                        }
                    }
                    .buttonStyle(.plain)
                    
                    Spacer()
                    
                    PhotosPicker(
                        selection: $feedPhotoItems,
                        maxSelectionCount: 5,
                        matching: .images
                    ) {
                        HStack(spacing: 4) {
                            if isProcessingPhotos {
                                ProgressView()
                                    .tint(.white)
                                    .frame(width: 16, height: 16)
                            } else {
                                Image(systemName: "photo.fill")
                            }
                            Text("Photo")
                        }
                        .font(.subheadline).bold()
                        .padding(.horizontal, 10)
                        .padding(.vertical, 8)
                        .background(isProcessingPhotos ? Color.gray : Color.accentGreen)
                        .foregroundColor(.white)
                        .cornerRadius(20)
                    }
                    .disabled(isProcessingPhotos)
                    .onChange(of: feedPhotoItems) { newItems in
                        guard !newItems.isEmpty else { return }
                        Task {
                            isProcessingPhotos = true
                            var loadedData: [Data] = []
                            for item in newItems {
                                if let data = try? await item.loadTransferable(type: Data.self) {
                                    loadedData.append(data)
                                }
                            }
                            self.loadedDataForSheet = loadedData
                            self.feedPhotoItems = []
                            isProcessingPhotos = false
                        }
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color(.systemGray6))
                .cornerRadius(30)
                .padding(.horizontal)
                
                // Content View
                if isLoading {
                    ProgressView("Loading Community...")
                        .padding(.top, 50)
                } else if posts.isEmpty {
                    EmptyStateView(icon: "message.circle", message: "No posts yet. Start a conversation now!")
                } else if postIndices.isEmpty {
                     EmptyStateView(icon: "magnifyingglass", message: "No posts match your filters.")
                } else {
                    List {
                        ForEach(postIndices, id: \.self) { index in
                            VStack(alignment: .leading) {
                                PostCard(
                                    post: $posts[index],
                                    onDelete: deletePostFromFeed
                                )
                                
                                NavigationLink(destination: PostDetailView(post: posts[index])) {
                                    EmptyView()
                                }
                                .opacity(0)
                                .frame(height: 0)
                            }
                            .listRowSeparator(.hidden)
                            .listRowInsets(EdgeInsets(top: 10, leading: 10, bottom: 10, trailing: 10))
                        }
                    }
                    .listStyle(.plain)
                    .refreshable {
                        await fetchPosts()
                    }
                }
            }
            .navigationBarHidden(true)
            .task { await fetchPosts() }
            .sheet(isPresented: $isCreatePostPresented) {
                CreatePostView(
                    postToEdit: nil,
                    onPostCreated: {
                        isCreatePostPresented = false
                        Task { await fetchPosts() }
                    }
                )
            }
            .sheet(item: $loadedDataForSheet) { photoData in
                CreatePostView(initialPhotoData: photoData, onPostCreated: {
                    loadedDataForSheet = nil
                    Task { await fetchPosts() }
                })
            }
        }
        .navigationViewStyle(.stack)
    }
    
    func fetchPosts() async {
        isLoading = true
        do {
            self.posts = try await communityManager.fetchPosts(filter: filterMode.rawValue)
        } catch {
            print("Failed to fetch posts: \(error)")
        }
        isLoading = false
    }
    
    private func deletePostFromFeed(postID: String) {
        posts.removeAll { $0.id == postID }
    }
}

extension Array: Identifiable where Element == Data {
    public var id: String {
        self.map { String($0.count) }.joined(separator: "-")
    }
}

enum CommunityFilter: String {
    case all, instructors, local, trending
}

struct PostCard: View {
    @Binding var post: Post
    let onDelete: (String) -> Void
    // Control whether this card shows comments list internally
    var showCommentsList: Bool = true
    
    @EnvironmentObject var communityManager: CommunityManager
    @EnvironmentObject var authManager: AuthManager

    @State private var currentImagePage = 0
    
    @State private var isCommenting: Bool = false
    @State private var commentText: String = ""
    @State private var isPostingComment: Bool = false
    @State private var fetchedComments: [Comment]? = nil
    @State private var isLoadingComments: Bool = false
    
    @State private var visibleCommentLimit: Int = 3
    @State private var expandedReplyIDs: Set<String> = [] // Track expanded replies
    
    @State private var replyingToComment: Comment? = nil
    @State private var editingComment: Comment? = nil // --- NEW STATE ---
    
    @FocusState private var isCommentFieldFocused: Bool
    
    @State private var isShowingEditSheet = false
    @State private var isShowingDeleteAlert = false
    
    private var allParentComments: [Comment] {
        (fetchedComments ?? [])
            .filter { $0.parentCommentID == nil }
            .sorted(by: { $0.timestamp < $1.timestamp })
    }
    
    private var visibleParentComments: [Comment] {
        Array(allParentComments.prefix(visibleCommentLimit))
    }
    
    private func replies(for parent: Comment) -> [Comment] {
        (fetchedComments ?? [])
            .filter { $0.parentCommentID == parent.id }
            .sorted(by: { $0.timestamp < $1.timestamp })
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            headerView
            contentView
            mediaView
            progressUpdateView
            Divider()
            reactionBar
            commentsSection
        }
        .padding(15)
        .background(Color(.systemBackground))
        .cornerRadius(15)
        .shadow(color: Color.textDark.opacity(0.1), radius: 8, x: 0, y: 4)
        .animation(.default, value: isCommenting)
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
        .alert("Delete Post?", isPresented: $isShowingDeleteAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                Task {
                    await deletePost()
                }
            }
        } message: {
            Text("Are you sure you want to delete this post? This action cannot be undone.")
        }
        .onChange(of: isCommenting) { _, newValue in
             if newValue && commentText.isEmpty {
                 isCommentFieldFocused = true
             }
        }
    }
    
    // MARK: - Subviews for PostCard
    
    private var headerView: some View {
        HStack(alignment: .top) {
            AsyncImage(url: URL(string: post.authorPhotoURL ?? "")) { phase in
                if let image = phase.image {
                    image.resizable().scaledToFill()
                } else {
                    Image(systemName: "person.circle.fill")
                        .resizable().foregroundColor(.secondaryGray)
                }
            }
            .frame(width: 40, height: 40)
            .clipShape(Circle())
            .background(Color.secondaryGray.clipShape(Circle()))
            
            VStack(alignment: .leading, spacing: 2) {
                Text(post.authorName).font(.headline)
                
                VStack(alignment: .leading, spacing: 2) {
                    if let location = post.location, !location.isEmpty {
                        HStack(spacing: 3) {
                            Image(systemName: "mappin.circle.fill")
                            Text(location)
                        }
                        .font(.caption)
                        .foregroundColor(.textLight)
                        .lineLimit(1)
                    }
                    
                    HStack(spacing: 4) {
                        Text(post.timestamp.timeAgoDisplay())
                        
                        if post.isEdited == true {
                            Text("• (edited)")
                        }
                    }
                    .font(.caption)
                    .foregroundColor(.textLight)
                }
            }
            
            Spacer()
            
            if post.authorID == authManager.user?.id {
                Menu {
                    Button {
                        isShowingEditSheet = true
                    } label: {
                        Label("Edit Post", systemImage: "pencil")
                    }
                    
                    Button(role: .destructive) {
                        isShowingDeleteAlert = true
                    } label: {
                        Label("Delete Post", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.headline)
                        .foregroundColor(.textLight)
                        .padding(5)
                }
                .buttonStyle(.plain)
            } else {
                Button("Follow") {
                    print("Following user \(post.authorID)...")
                }
                .buttonStyle(.bordered)
                .tint(.primaryBlue)
                .font(.caption.bold())
                .buttonStyle(.plain)
            }
        }
    }
    
    @ViewBuilder
    private var contentView: some View {
        if let content = post.content {
            Text(content)
                .font(.body)
                .padding(.bottom, 5)
        }
    }
    
    @ViewBuilder
    private var mediaView: some View {
        if let mediaURLs = post.mediaURLs, !mediaURLs.isEmpty {
            ZStack(alignment: .topTrailing) {
                TabView(selection: $currentImagePage) {
                    ForEach(Array(mediaURLs.enumerated()), id: \.offset) { index, urlString in
                        if let url = URL(string: urlString) {
                            AsyncImage(url: url) { phase in
                                switch phase {
                                case .success(let image):
                                    image
                                        .resizable()
                                        .scaledToFit()
                                        .cornerRadius(10)
                                case .failure:
                                    Image(systemName: "photo.on.rectangle")
                                        .foregroundColor(.textLight)
                                        .frame(maxWidth: .infinity, alignment: .center)
                                case .empty:
                                    ProgressView()
                                        .frame(maxWidth: .infinity, minHeight: 250, alignment: .center)
                                @unknown default:
                                    EmptyView()
                                }
                            }
                            .tag(index)
                        }
                    }
                }
                .frame(height: 350)
                .tabViewStyle(.page(indexDisplayMode: .never))
                .cornerRadius(10)
                
                if mediaURLs.count > 1 {
                    Text("\(currentImagePage + 1)/\(mediaURLs.count)")
                        .font(.caption.bold())
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.black.opacity(0.7))
                        .foregroundColor(.white)
                        .cornerRadius(10)
                        .padding(10)
                }
            }
            .padding(.vertical, 5)
        }
    }
    
    @ViewBuilder
    private var progressUpdateView: some View {
        if post.postType == .progressUpdate {
            Text("📈 Progress Update: 65% Mastery Achieved!")
                .font(.subheadline).bold()
                .foregroundColor(.primaryBlue)
                .padding(5)
                .background(Color.secondaryGray)
                .cornerRadius(5)
        }
    }
    
    private var reactionBar: some View {
        HStack {
            ReactionButton(
                post: $post,
                reactionType: "thumbsup",
                icon: "hand.thumbsup.fill",
                color: .primaryBlue
            )
            .buttonStyle(.plain)

            ReactionButton(
                post: $post,
                reactionType: "fire",
                icon: "flame.fill",
                color: .orange
            )
            .buttonStyle(.plain)
            
            ReactionButton(
                post: $post,
                reactionType: "heart",
                icon: "heart.fill",
                color: .warningRed
            )
            .buttonStyle(.plain)
            
            Spacer()
            
            Button {
                withAnimation { isCommenting.toggle() }
                if isCommenting && fetchedComments == nil {
                    Task { await fetchComments() }
                }
                if isCommenting == false {
                    replyingToComment = nil
                    editingComment = nil
                }
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "message")
                    Text("\(post.commentsCount) Comments")
                }
                .font(.caption)
                .foregroundColor(.textLight)
            }
            .buttonStyle(.plain)
        }
    }
    
    @ViewBuilder
    private var commentsSection: some View {
        if showCommentsList && isCommenting {
            VStack(alignment: .leading, spacing: 10) {
                
                if isLoadingComments {
                    ProgressView()
                        .padding(.vertical, 5)
                        .frame(maxWidth: .infinity, alignment: .center)
                } else if let comments = fetchedComments, !comments.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        
                        ForEach(visibleParentComments) { parent in
                            let isExpanded = expandedReplyIDs.contains(parent.id ?? "")
                            
                            // --- FeedCommentRow for Parent Comments ---
                            FeedCommentRow(
                                comment: parent,
                                isExpanded: isExpanded,
                                currentUserID: authManager.user?.id,
                                postAuthorID: post.authorID,
                                onReply: { handleReply(to: parent) },
                                onToggleReplies: {
                                    withAnimation {
                                        if isExpanded {
                                            expandedReplyIDs.remove(parent.id ?? "")
                                        } else {
                                            expandedReplyIDs.insert(parent.id ?? "")
                                        }
                                    }
                                },
                                onEdit: { handleEdit(parent) },
                                onDelete: { handleDeleteComment(parent) }
                            )
                            .buttonStyle(.plain)
                            
                            // --- REPLIES LOGIC ---
                            let replyComments = replies(for: parent)
                            
                            if !replyComments.isEmpty && isExpanded {
                                ForEach(replyComments) { reply in
                                    FeedCommentRow(
                                        comment: reply,
                                        isExpanded: false,
                                        currentUserID: authManager.user?.id,
                                        postAuthorID: post.authorID,
                                        onReply: { handleReply(to: reply) },
                                        onEdit: { handleEdit(reply) },
                                        onDelete: { handleDeleteComment(reply) }
                                        // 'onToggleReplies' is defaulted to nil in init
                                    )
                                    .padding(.leading, 30)
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                        
                        if allParentComments.count > visibleCommentLimit {
                            Button {
                                withAnimation {
                                    visibleCommentLimit += 5
                                }
                            } label: {
                                HStack {
                                    Spacer()
                                    Text("View 5 more comments")
                                        .font(.caption).bold()
                                        .foregroundColor(.primaryBlue)
                                    Spacer()
                                }
                                .padding(.vertical, 5)
                            }
                            .buttonStyle(.plain)
                        }
                        
                        if post.commentsCount > comments.count {
                            Text("View all \(post.commentsCount) comments...")
                                .font(.caption).bold()
                                .foregroundColor(.primaryBlue)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.top, 4)
                        }
                    }
                    .padding(.top, 5)
                } else if fetchedComments != nil {
                    Text("No comments yet. Be the first!")
                        .font(.caption).foregroundColor(.textLight)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.vertical, 5)
                }
                
                // --- REPLY / EDIT INDICATORS ---
                if let replyingTo = replyingToComment {
                    HStack {
                        Text("Replying to @\(replyingTo.authorName)")
                            .font(.caption).bold()
                            .foregroundColor(.textLight)
                        Spacer()
                        Button {
                            replyingToComment = nil
                            commentText = ""
                        } label: {
                            Image(systemName: "xmark")
                                .font(.caption).bold()
                                .foregroundColor(.textLight)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    
                    if let editing = editingComment {
                        HStack {
                            Text("Editing comment")
                                .font(.caption).bold()
                                .foregroundColor(.primaryBlue)
                            Spacer()
                            Button {
                                editingComment = nil
                                commentText = ""
                            } label: {
                                Image(systemName: "xmark")
                                    .font(.caption).bold()
                                    .foregroundColor(.textLight)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    
                    HStack(spacing: 8) {
                        TextField(replyingToComment == nil ? "Write a comment..." : "Write your reply...", text: $commentText)
                            .padding(8)
                            .background(Color.secondaryGray.opacity(0.7))
                            .cornerRadius(10)
                            .focused($isCommentFieldFocused)
                        
                        // --- SEND ICON BUTTON ---
                        Button {
                            Task { await postComment() }
                        } label: {
                            if isPostingComment {
                                ProgressView()
                            } else {
                                Image(systemName: "paperplane.fill")
                                    .foregroundColor(.primaryBlue)
                            }
                        }
                        .buttonStyle(.plain)
                        .disabled(commentText.isEmpty || isPostingComment)
                    }
                }
                .padding(.top, 8)
                .transition(.opacity.combined(with: .move(edge: .top)))
                .animation(.default, value: replyingToComment)
                .animation(.default, value: editingComment)
            }
        }
    
    // MARK: - Logic Functions
    
    private func deletePost() async {
        guard let postID = post.id else {
            print("Post ID not found, cannot delete.")
            return
        }
        
        do {
            try await communityManager.deletePost(postID: postID)
            await MainActor.run {
                onDelete(postID)
            }
            
        } catch {
            print("Error deleting post: \(error.localizedDescription)")
        }
    }

    
    private func handleReply(to comment: Comment) {
        // Clear edit state if active
        editingComment = nil
        
        if let parentID = comment.parentCommentID {
            self.replyingToComment = fetchedComments?.first(where: { $0.id == parentID })
        } else {
            self.replyingToComment = comment
        }
        commentText = "@\(comment.authorName) "
        isCommentFieldFocused = true
    }
    
    // --- NEW FUNCTION ---
    private func handleEdit(_ comment: Comment) {
        // Clear reply state if active
        replyingToComment = nil
        
        self.editingComment = comment
        self.commentText = comment.content
        isCommentFieldFocused = true
    }
    
    // --- NEW FUNCTION ---
    private func handleDeleteComment(_ comment: Comment) {
        guard let postID = post.id, let commentID = comment.id else { return }
        
        Task {
            do {
                try await communityManager.deleteComment(postID: postID, commentID: commentID, parentCommentID: comment.parentCommentID)
                
                // Refresh list locally
                post.commentsCount -= 1
                await fetchComments()
                
            } catch {
                print("Error deleting comment: \(error)")
            }
        }
    }
    
    private func fetchComments() async {
        guard let postID = post.id else { return }
        isLoadingComments = true
        do {
            self.fetchedComments = try await communityManager.fetchComments(for: postID)
        } catch {
            print("Failed to fetch comments: \(error)")
            self.fetchedComments = []
        }
        isLoadingComments = false
    }
    
    private func postComment() async {
        guard let postID = post.id,
              let author = authManager.user,
              let authorID = author.id else {
            print("Cannot post comment: Missing IDs or user object")
            return
        }
        
        let content = commentText
        
        isPostingComment = true
        
        // --- HANDLE EDIT ---
        if let editing = editingComment, let commentID = editing.id {
            do {
                try await communityManager.updateComment(postID: postID, commentID: commentID, newContent: content)
                
                editingComment = nil
                commentText = ""
                isCommentFieldFocused = false
                
                // Refresh comments
                await fetchComments()
                
            } catch {
                print("Failed to update comment: \(error)")
            }
            isPostingComment = false
            return
        }
        
        // --- HANDLE CREATE ---
        let parentID = replyingToComment?.id
        
        do {
            try await communityManager.addComment(
                postID: postID,
                authorID: authorID,
                authorName: author.name ?? "User",
                authorRole: author.role,
                authorPhotoURL: author.photoURL,
                content: content,
                parentCommentID: parentID
            )
            
            commentText = ""
            replyingToComment = nil
            isCommentFieldFocused = false
            post.commentsCount += 1
            await fetchComments()
            
        } catch {
            print("Failed to post comment from feed: \(error.localizedDescription)")
        }
        isPostingComment = false
        isCommentFieldFocused = false
    }
}

struct ReactionButton: View {
    @EnvironmentObject var communityManager: CommunityManager
    
    @Binding var post: Post
    let reactionType: String
    let icon: String
    var color: Color
    
    private var count: Int {
        post.reactionsCount[reactionType] ?? 0
    }
    
    @State private var isDisabled = false

    var body: some View {
        Button {
            isDisabled = true
            
            Task {
                guard let postID = post.id else {
                    isDisabled = false
                    return
                }
                
                do {
                    try await communityManager.addReaction(postID: postID, reactionType: reactionType)
                    
                    post.reactionsCount[reactionType, default: 0] += 1
                    
                } catch {
                    print("Failed to add reaction: \(error.localizedDescription)")
                }
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    isDisabled = false
                }
            }
        } label: {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .foregroundColor(color)
                Text("\(count)")
                    .font(.subheadline)
                    .foregroundColor(.textDark)
            }
            .padding(.trailing, 10)
        }
        .disabled(isDisabled)
    }
}

// --- LOCALLY DEFINED COMMENT ROW TO PREVENT REDECLARATION ---
struct FeedCommentRow: View {
    let comment: Comment
    let isExpanded: Bool
    let currentUserID: String?
    let postAuthorID: String?
    
    let onReply: (() -> Void)?
    let onToggleReplies: (() -> Void)?
    let onEdit: (() -> Void)?
    let onDelete: (() -> Void)?
    
    // Added Init with default nil to fix "Missing Argument" error
    init(comment: Comment, isExpanded: Bool = false, currentUserID: String? = nil, postAuthorID: String? = nil, onReply: (() -> Void)? = nil, onToggleReplies: (() -> Void)? = nil, onEdit: (() -> Void)? = nil, onDelete: (() -> Void)? = nil) {
        self.comment = comment
        self.isExpanded = isExpanded
        self.currentUserID = currentUserID
        self.postAuthorID = postAuthorID
        self.onReply = onReply
        self.onToggleReplies = onToggleReplies
        self.onEdit = onEdit
        self.onDelete = onDelete
    }
    
    // Permissions Logic
    var canEdit: Bool {
        return currentUserID == comment.authorID
    }
    
    var canDelete: Bool {
        return currentUserID == comment.authorID || currentUserID == postAuthorID
    }
    
    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            AsyncImage(url: URL(string: comment.authorPhotoURL ?? "")) { phase in
                if let image = phase.image {
                    image.resizable().scaledToFill()
                } else {
                    Image(systemName: "person.circle.fill")
                        .resizable().foregroundColor(.secondaryGray)
                }
            }
            .frame(width: 35, height: 35)
            .clipShape(Circle())
            .background(Color.secondaryGray.clipShape(Circle()))
            
            VStack(alignment: .leading, spacing: 4) {
                // --- HEADER ROW (Name, Time, Edited, Spacer, MENU) ---
                HStack(alignment: .center) {
                    Text(comment.authorName)
                        .font(.subheadline).bold()
                    Text("• \(comment.timestamp.timeAgoDisplay())")
                        .font(.caption).foregroundColor(.textLight)
                    
                    if comment.isEdited == true {
                        Text("(edited)")
                            .font(.caption2)
                            .foregroundColor(.textLight)
                            .italic()
                    }
                    
                    Spacer() // Pushes Menu to the right
                    
                    // --- MENU IN HEADER ---
                    if canEdit || canDelete {
                        Menu {
                            if canEdit {
                                Button(action: { onEdit?() }) {
                                    Label("Edit", systemImage: "pencil")
                                }
                            }
                            if canDelete {
                                Button(role: .destructive, action: { onDelete?() }) {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                        } label: {
                            Image(systemName: "ellipsis")
                                .font(.caption).foregroundColor(.textLight)
                                .frame(width: 20, height: 20)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                }
                
                Text(comment.content)
                    .font(.body)
                
                // --- FOOTER ROW (Reply, View Replies) ---
                HStack(spacing: 12) {
                    Button("Reply") { onReply?() }
                        .font(.caption).bold().foregroundColor(.textLight)
                        .buttonStyle(.plain)
                    
                    if comment.repliesCount > 0 {
                        Button { onToggleReplies?() } label: {
                            HStack(spacing: 3) {
                                Text("•")
                                Text("\(comment.repliesCount) replies")
                                Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                            }
                            .font(.caption).bold().foregroundColor(.primaryBlue)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }
}

// --- ADDED Date extension to fix 'Value of type Date has no member timeAgoDisplay' ---
extension Date {
    func timeAgoDisplay() -> String {
        let secondsAgo = Int(Date().timeIntervalSince(self))

        if secondsAgo < 60 {
            return "Just now"
        }
        
        let minutes = secondsAgo / 60
        if minutes < 60 {
            return "\(minutes)m ago"
        }
        
        let hours = minutes / 60
        if hours < 24 {
            return "\(hours)h ago"
        }
        
        let days = hours / 24
        if days < 7 {
            return "\(days)d ago"
        }
        
        let weeks = days / 7
        if weeks < 4 {
            return "\(weeks)w ago"
        }
        
        let months = days / 30 // Approximate
        if months < 12 {
            return "\(months)mo ago"
        }
        
        let years = months / 12
        return "\(years)y ago"
    }
}
