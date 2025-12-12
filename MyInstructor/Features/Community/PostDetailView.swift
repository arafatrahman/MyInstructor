// File: MyInstructor/Features/Community/PostDetailView.swift
// --- UPDATED: Ensures exact same hierarchical & collapsible behavior as CommunityFeedView ---

import SwiftUI

struct PostDetailView: View {
    @EnvironmentObject var authManager: AuthManager
    @EnvironmentObject var communityManager: CommunityManager
    @Environment(\.dismiss) var dismiss
    
    @State var post: Post
    
    @State private var commentText: String = ""
    @State private var isReportFlowPresented = false
    
    // We rely on communityManager.comments for live updates
    
    @State private var visibleCommentLimit: Int = 10
    
    // --- Collapsed by default (empty set) ---
    @State private var expandedReplyIDs: Set<String> = []
    
    @State private var replyingToComment: Comment? = nil
    @State private var editingComment: Comment? = nil
    
    @FocusState private var isCommentFieldFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 15) {
                    
                    // Reusing the PostCard from the Feed, but hiding the internal comments list
                    PostCard(
                        post: $post,
                        onDelete: { _ in dismiss() },
                        showCommentsList: false
                    )
                    
                    // Reactions Summary
                    HStack {
                        Text("\(post.reactionsCount.values.reduce(0, +)) Reactions")
                            .font(.subheadline).bold()
                        Spacer()
                        
                        ReactionActionButton(post: $post, reactionType: "thumbsup", icon: "hand.thumbsup.fill", color: .primaryBlue)
                        ReactionActionButton(post: $post, reactionType: "fire", icon: "flame.fill", color: .orange)
                        ReactionActionButton(post: $post, reactionType: "heart", icon: "heart.fill", color: .warningRed)
                    }
                    .padding(.horizontal)
                    
                    Divider()
                    
                    // Comments Section
                    Text("Comments (\(communityManager.comments.count))")
                        .font(.headline)
                        .padding(.horizontal)
                    
                    VStack(alignment: .leading, spacing: 20) {
                        if communityManager.comments.isEmpty {
                            Text("No comments yet.")
                                .foregroundColor(.textLight)
                                .padding(.top, 10)
                        } else {
                            // Filter and sort parent comments from LIVE data
                            let allParentComments = communityManager.comments
                                .filter { $0.parentCommentID == nil }
                                .sorted(by: { $0.timestamp < $1.timestamp })
                            
                            // Show only a subset initially
                            let visibleParents = Array(allParentComments.prefix(visibleCommentLimit))
                            
                            ForEach(visibleParents) { comment in
                                let isExpanded = expandedReplyIDs.contains(comment.id ?? "")
                                
                                // Parent Comment Row
                                CommentRow(
                                    comment: comment,
                                    isExpanded: isExpanded,
                                    currentUserID: authManager.user?.id,
                                    postAuthorID: post.authorID,
                                    onReply: { replyTo(comment) },
                                    onToggleReplies: {
                                        withAnimation {
                                            if isExpanded { expandedReplyIDs.remove(comment.id ?? "") }
                                            else { expandedReplyIDs.insert(comment.id ?? "") }
                                        }
                                    },
                                    onEdit: { editComment(comment) },
                                    onDelete: { deleteComment(comment) }
                                )
                                
                                // Replies (Nested & Collapsible)
                                if isExpanded {
                                    let replyComments = communityManager.comments
                                        .filter { $0.parentCommentID == comment.id }
                                        .sorted(by: { $0.timestamp < $1.timestamp })
                                    
                                    ForEach(replyComments) { reply in
                                        CommentRow(
                                            comment: reply,
                                            isExpanded: false,
                                            currentUserID: authManager.user?.id,
                                            postAuthorID: post.authorID,
                                            onReply: { replyTo(reply) },
                                            onEdit: { editComment(reply) },
                                            onDelete: { deleteComment(reply) }
                                        )
                                        .padding(.leading, 30) // --- Indentation ---
                                    }
                                }
                            }
                            
                            // "View More" Button
                            if allParentComments.count > visibleCommentLimit {
                                Button {
                                    withAnimation { visibleCommentLimit += 5 }
                                } label: {
                                    Text("View 5 more comments")
                                        .font(.subheadline).bold()
                                        .foregroundColor(.primaryBlue)
                                }
                                .frame(maxWidth: .infinity, alignment: .center)
                                .padding(.vertical, 10)
                            }
                        }
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 20)
                }
            }
            
            // Replying / Editing Indicators
            if let replyingTo = replyingToComment {
                HStack {
                    Text("Replying to @\(replyingTo.authorName)")
                        .font(.caption).bold()
                    Spacer()
                    Button {
                        replyingToComment = nil
                        commentText = ""
                        isCommentFieldFocused = false
                    } label: {
                        Image(systemName: "xmark").font(.caption).bold()
                    }
                }
                .padding(.horizontal)
                .padding(.vertical, 8)
                .background(Color.secondaryGray)
            }
            
            if let editing = editingComment {
                HStack {
                    Text("Editing comment")
                        .font(.caption).bold().foregroundColor(.primaryBlue)
                    Spacer()
                    Button {
                        editingComment = nil
                        commentText = ""
                        isCommentFieldFocused = false
                    } label: {
                        Image(systemName: "xmark").font(.caption).bold()
                    }
                }
                .padding(.horizontal)
                .padding(.vertical, 8)
                .background(Color.secondaryGray)
            }
            
            Divider()
            
            // Input Area
            CommentInputView(
                commentText: $commentText,
                isReportFlowPresented: $isReportFlowPresented,
                isCommentFieldFocused: $isCommentFieldFocused,
                onPost: {
                    Task { await postComment() }
                }
            )
        }
        .animation(.default, value: replyingToComment)
        .animation(.default, value: editingComment)
        .navigationTitle("Post Detail")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $isReportFlowPresented) {
            ReportFlowView()
        }
        .task {
            // Start listening for real-time updates when view appears
            if let id = post.id {
                communityManager.listenToComments(for: id)
            }
        }
        .onDisappear {
            // Stop listening when leaving the screen
            communityManager.stopListeningToComments()
        }
        .onTapGesture {
            isCommentFieldFocused = false
        }
    }
    
    // MARK: - Logic Functions
    
    private func replyTo(_ comment: Comment) {
        // Clear edit state if active
        editingComment = nil
        
        if let parentID = comment.parentCommentID {
            // If replying to a reply, link it to the parent
            self.replyingToComment = communityManager.comments.first(where: { $0.id == parentID })
        } else {
            self.replyingToComment = comment
        }
        commentText = "@\(comment.authorName) "
        isCommentFieldFocused = true
    }
    
    private func editComment(_ comment: Comment) {
        // Clear reply state if active
        replyingToComment = nil
        
        self.editingComment = comment
        self.commentText = comment.content
        isCommentFieldFocused = true
    }
    
    private func deleteComment(_ comment: Comment) {
        guard let postID = post.id, let commentID = comment.id else { return }
        Task {
            do {
                try await communityManager.deleteComment(postID: postID, commentID: commentID, parentCommentID: comment.parentCommentID)
            } catch {
                print("Error deleting comment: \(error)")
            }
        }
    }
    
    private func postComment() async {
        guard let postID = post.id,
              let author = authManager.user,
              let authorID = author.id else { return }
        
        let content = commentText
        
        // --- HANDLE EDIT ---
        if let editing = editingComment, let commentID = editing.id {
            do {
                try await communityManager.updateComment(postID: postID, commentID: commentID, newContent: content)
                editingComment = nil
                commentText = ""
                isCommentFieldFocused = false
            } catch {
                print("Failed to update comment: \(error)")
            }
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
            
        } catch {
            print("Failed to post comment: \(error.localizedDescription)")
        }
    }
}

// MARK: - Supporting Views

struct ReactionActionButton: View {
    @EnvironmentObject var communityManager: CommunityManager
    @EnvironmentObject var authManager: AuthManager
    @Binding var post: Post
    let reactionType: String
    let icon: String
    var color: Color
    private var count: Int { post.reactionsCount[reactionType] ?? 0 }
    @State private var isDisabled = false
    
    var body: some View {
        Button {
            isDisabled = true
            Task {
                guard let postID = post.id, let user = authManager.user else { isDisabled = false; return }
                do {
                    // Send user object for notification generation
                    try await communityManager.addReaction(postID: postID, user: user, reactionType: reactionType)
                    post.reactionsCount[reactionType, default: 0] += 1
                } catch { print("Failed: \(error)") }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { isDisabled = false }
            }
        } label: {
            HStack(spacing: 4) {
                Image(systemName: icon).foregroundColor(color)
                if count > 0 { Text("\(count)") }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(Color.secondaryGray)
            .foregroundColor(color)
            .cornerRadius(15)
        }
        .disabled(isDisabled)
    }
}

// --- UPDATED CommentRow with Context Menu and Reply Button ---
struct CommentRow: View {
    let comment: Comment
    let isExpanded: Bool
    let currentUserID: String?
    let postAuthorID: String?
    
    let onReply: (() -> Void)?
    let onToggleReplies: (() -> Void)?
    let onEdit: (() -> Void)?
    let onDelete: (() -> Void)?
    
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
    
    var canEdit: Bool {
        return currentUserID == comment.authorID
    }
    
    // Author of comment OR Author of post can delete
    var canDelete: Bool {
        return currentUserID == comment.authorID || currentUserID == postAuthorID
    }
    
    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            // Avatar
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
                // Header: Name • Time • (edited)
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
                    
                    Spacer()
                }
                
                Text(comment.content)
                    .font(.body)
                
                // Footer: Reply Button & View Replies Toggle
                HStack(spacing: 12) {
                    Button("Reply") { onReply?() }
                        .font(.caption).bold().foregroundColor(.primaryBlue)
                        .buttonStyle(.plain)
                    
                    if comment.repliesCount > 0 {
                        Button { onToggleReplies?() } label: {
                            HStack(spacing: 3) {
                                Text("•")
                                Text("View \(comment.repliesCount) replies")
                                Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                            }
                            .font(.caption).bold().foregroundColor(.textLight)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle()) // Make entire row interactable for long press
        .contextMenu {
            if canEdit {
                Button(action: { onEdit?() }) {
                    Label("Edit Comment", systemImage: "pencil")
                }
            }
            if canDelete {
                Button(role: .destructive, action: { onDelete?() }) {
                    Label("Delete Comment", systemImage: "trash")
                }
            }
        }
    }
}

struct CommentInputView: View {
    @Binding var commentText: String
    @Binding var isReportFlowPresented: Bool
    var isCommentFieldFocused: FocusState<Bool>.Binding
    
    var onPost: () -> Void
    
    var body: some View {
        HStack {
            TextField("Add a comment...", text: $commentText)
                .padding(10)
                .background(Color.secondaryGray)
                .cornerRadius(20)
                .focused(isCommentFieldFocused)
            
            // Send Button (Icon)
            Button {
                onPost()
            } label: {
                Image(systemName: "paperplane.fill")
                    .font(.title2)
                    .foregroundColor(commentText.isEmpty ? .secondary : .primaryBlue)
            }
            .buttonStyle(.plain)
            .disabled(commentText.isEmpty)
            
            // Report Menu
            Menu {
                Button("Report Post", role: .destructive) {
                    isReportFlowPresented = true
                }
            } label: {
                Image(systemName: "ellipsis.circle.fill")
                    .font(.title2)
                    .foregroundColor(.textDark)
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
    }
}
