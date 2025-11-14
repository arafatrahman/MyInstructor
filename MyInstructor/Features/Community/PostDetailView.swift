// File: arafatrahman/myinstructor/MyInstructor-main/MyInstructor/Features/Community/PostDetailView.swift
// --- FINAL VERSION ---
// --- UPDATED: Defines CommentRow, ReactionActionButton, and CommentInputView ---
// --- UPDATED: CommentRow now visual (with photo) and supports onReply callback ---
// --- UPDATED: Shows nested comments and handles reply-to-user logic ---

import SwiftUI

// Flow Item 20: Post Detail
struct PostDetailView: View {
    @EnvironmentObject var authManager: AuthManager
    @EnvironmentObject var communityManager: CommunityManager
    
    @State var post: Post
    
    @State private var commentText: String = ""
    @State private var isReportFlowPresented = false
    
    @State private var comments: [Comment] = []
    
    // --- NEW: State for reply logic ---
    @State private var replyingToComment: Comment? = nil
    @FocusState private var isCommentFieldFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 15) {
                    
                    PostCard(post: $post)
                    
                    // Reactions Summary
                    HStack {
                        Text("\(post.reactionsCount.values.reduce(0, +)) Reactions")
                            .font(.subheadline).bold()
                        Spacer()
                        
                        ReactionActionButton(
                            post: $post,
                            reactionType: "thumbsup",
                            icon: "hand.thumbsup",
                            color: .primaryBlue
                        )
                        ReactionActionButton(
                            post: $post,
                            reactionType: "fire",
                            icon: "flame",
                            color: .orange
                        )
                        ReactionActionButton(
                            post: $post,
                            reactionType: "heart",
                            icon: "heart",
                            color: .warningRed
                        )
                    }
                    .padding(.horizontal)
                    
                    Divider()
                    
                    // Comments Section
                    Text("Comments (\(post.commentsCount))")
                        .font(.headline)
                        .padding(.horizontal)
                    
                    VStack(alignment: .leading, spacing: 20) {
                        if comments.isEmpty {
                            Text("No comments yet.")
                                .foregroundColor(.textLight)
                                .padding(.top, 10)
                        } else {
                            // --- *** UPDATED TO SUPPORT NESTED REPLIES *** ---
                            let parentComments = comments.filter { $0.parentCommentID == nil }.sorted(by: { $0.timestamp < $1.timestamp })
                            
                            ForEach(parentComments) { comment in
                                // 1. Show Parent Comment
                                CommentRow(comment: comment, onReply: {
                                    replyTo(comment)
                                })
                                
                                // 2. Show Replies
                                let replies = comments.filter { $0.parentCommentID == comment.id }.sorted(by: { $0.timestamp < $1.timestamp })
                                ForEach(replies) { reply in
                                    CommentRow(comment: reply, onReply: {
                                        replyTo(reply) // Replying to a reply still replies to the parent
                                    })
                                    .padding(.leading, 30) // Indent replies
                                }
                            }
                            // --- *** END OF UPDATE *** ---
                        }
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 20)
                }
            }
            
            // --- NEW: Show who you are replying to ---
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
                        Image(systemName: "xmark")
                            .font(.caption).bold()
                    }
                }
                .padding(.horizontal)
                .padding(.vertical, 8)
                .background(Color.secondaryGray)
                .transition(.opacity.combined(with: .move(edge: .bottom)))
            }
            
            // Bottom Actions: Comment box
            Divider()
            CommentInputView(
                commentText: $commentText,
                isReportFlowPresented: $isReportFlowPresented,
                isCommentFieldFocused: $isCommentFieldFocused, // Pass focus state
                onPost: { // Pass post action
                    Task {
                        await postComment()
                    }
                }
            )
        }
        .animation(.default, value: replyingToComment)
        .navigationTitle("Post Detail")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $isReportFlowPresented) {
            ReportFlowView() // Flow Item 25
        }
        .task {
            await fetchComments()
        }
        .onTapGesture {
            isCommentFieldFocused = false // Dismiss keyboard on tap
        }
    }
    
    private func fetchComments() async {
        guard let postID = post.id else { return }
        print("Fetching comments for post \(postID)")
        do {
            self.comments = try await communityManager.fetchComments(for: postID)
        } catch {
            print("Failed to fetch comments: \(error.localizedDescription)")
        }
    }
    
    // --- NEW HELPER ---
    private func replyTo(_ comment: Comment) {
        // We always reply to the top-level parent
        if let parentID = comment.parentCommentID {
            // This is a reply to a reply, find the original parent
            self.replyingToComment = comments.first(where: { $0.id == parentID })
        } else {
            // This is a top-level comment
            self.replyingToComment = comment
        }
        commentText = "@\(comment.authorName) "
        isCommentFieldFocused = true
    }
    
    // --- NEW POST COMMENT LOGIC ---
    private func postComment() async {
        guard let postID = post.id,
              let author = authManager.user,
              let authorID = author.id else {
            print("Cannot post comment: Missing IDs or user object")
            return
        }
        
        let content = commentText
        let parentID = replyingToComment?.id // Get ID of comment we're replying to
        
        do {
            try await communityManager.addComment(
                postID: postID,
                authorID: authorID,
                authorName: author.name ?? "User",
                authorRole: author.role,
                authorPhotoURL: author.photoURL,
                content: content,
                parentCommentID: parentID // Pass the parentID
            )
            
            // Success: Clear state and re-fetch
            commentText = ""
            replyingToComment = nil
            isCommentFieldFocused = false
            post.commentsCount += 1 // Update local post
            await fetchComments() // Refresh the list
            
        } catch {
            print("Failed to post comment: \(error.localizedDescription)")
            // TODO: Show an error alert
        }
    }
}

// --- *** THIS STRUCT IS NOW DEFINED HERE *** ---
// Helper: Reaction Action Button
struct ReactionActionButton: View {
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
                if count > 0 {
                    Text("\(count)")
                }
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

// --- *** THIS STRUCT IS NOW DEFINED HERE *** ---
// Helper: Comment Row
struct CommentRow: View {
    let comment: Comment
    let onReply: (() -> Void)?
    
    init(comment: Comment, onReply: (() -> Void)? = nil) {
        self.comment = comment
        self.onReply = onReply
    }
    
    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            // --- NEW: Author Photo ---
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
            
            // --- Main Content ---
            VStack(alignment: .leading, spacing: 4) {
                // Author Name + Time
                HStack(alignment: .firstTextBaseline) {
                    Text(comment.authorName)
                        .font(.subheadline).bold()
                    // --- Use custom time ago string ---
                    Text("• \(comment.timestamp.timeAgoDisplay())")
                        .font(.caption).foregroundColor(.textLight)
                    Spacer()
                }
                
                // Content
                Text(comment.content)
                    .font(.body)
                
                // Actions
                HStack {
                    // --- Call the onReply closure ---
                    Button("Reply") {
                        onReply?()
                    }
                    .font(.caption).bold().foregroundColor(.textLight)
                    .buttonStyle(.plain)
                    
                    if comment.repliesCount > 0 {
                        // This is a tappable button
                        Button {
                            onReply?() // Replying is the same as viewing replies
                        } label: {
                            Text("• \(comment.repliesCount) replies")
                                .font(.caption).bold().foregroundColor(.primaryBlue)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }
}


// --- *** THIS STRUCT IS NOW DEFINED HERE *** ---
// Helper: Comment Input and More Menu
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
            
            Button("Post") {
                onPost()
            }
            .buttonStyle(.plain)
            .foregroundColor(.primaryBlue)
            .disabled(commentText.isEmpty)
            
            // More actions menu: Save, Share, Report
            Menu {
                Button("Save Post") { /* ... */ }
                Button("Share") { /* ... */ }
                Divider()
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
