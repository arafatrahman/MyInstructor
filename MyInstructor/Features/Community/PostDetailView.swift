// File: arafatrahman/myinstructor/MyInstructor-main/MyInstructor/Features/Community/PostDetailView.swift
// --- UPDATED: Default visible comments set to 3. 'View More' adds 5. ---

import SwiftUI

// Flow Item 20: Post Detail
struct PostDetailView: View {
    @EnvironmentObject var authManager: AuthManager
    @EnvironmentObject var communityManager: CommunityManager
    @Environment(\.dismiss) var dismiss
    
    @State var post: Post
    
    @State private var commentText: String = ""
    @State private var isReportFlowPresented = false
    
    @State private var comments: [Comment] = []
    
    // --- *** MODIFIED: START WITH 3 COMMENTS *** ---
    @State private var visibleCommentLimit: Int = 3
    
    @State private var replyingToComment: Comment? = nil
    @FocusState private var isCommentFieldFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 15) {
                    
                    PostCard(
                        post: $post,
                        onDelete: { _ in
                            // When deleted from the detail view, just dismiss.
                            // The feed view will refresh itself.
                            dismiss()
                        }
                    )
                    
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
                            // 1. Prepare Parent Comments
                            let allParentComments = comments
                                .filter { $0.parentCommentID == nil }
                                .sorted(by: { $0.timestamp < $1.timestamp })
                            
                            // 2. Slice for Visibility
                            let visibleParents = Array(allParentComments.prefix(visibleCommentLimit))
                            
                            ForEach(visibleParents) { comment in
                                CommentRow(comment: comment, onReply: {
                                    replyTo(comment)
                                })
                                
                                let replies = comments
                                    .filter { $0.parentCommentID == comment.id }
                                    .sorted(by: { $0.timestamp < $1.timestamp })
                                
                                ForEach(replies) { reply in
                                    CommentRow(comment: reply, onReply: {
                                        replyTo(reply)
                                    })
                                    .padding(.leading, 30)
                                }
                            }
                            
                            // 3. View More Button
                            if allParentComments.count > visibleCommentLimit {
                                Button {
                                    withAnimation {
                                        visibleCommentLimit += 5
                                    }
                                } label: {
                                    HStack {
                                        Spacer()
                                        Text("View 5 more comments")
                                            .font(.subheadline).bold()
                                            .foregroundColor(.primaryBlue)
                                        Spacer()
                                    }
                                    .padding(.vertical, 10)
                                }
                            }
                        }
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 20)
                }
            }
            
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
            
            Divider()
            CommentInputView(
                commentText: $commentText,
                isReportFlowPresented: $isReportFlowPresented,
                isCommentFieldFocused: $isCommentFieldFocused,
                onPost: {
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
            ReportFlowView()
        }
        .task {
            await fetchComments()
        }
        .onTapGesture {
            isCommentFieldFocused = false
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
    
    private func replyTo(_ comment: Comment) {
        if let parentID = comment.parentCommentID {
            self.replyingToComment = comments.first(where: { $0.id == parentID })
        } else {
            self.replyingToComment = comment
        }
        commentText = "@\(comment.authorName) "
        isCommentFieldFocused = true
    }
    
    private func postComment() async {
        guard let postID = post.id,
              let author = authManager.user,
              let authorID = author.id else {
            print("Cannot post comment: Missing IDs or user object")
            return
        }
        
        let content = commentText
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
            print("Failed to post comment: \(error.localizedDescription)")
        }
    }
}

// ... (ReactionActionButton struct) ...
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

// ... (CommentRow struct) ...
struct CommentRow: View {
    let comment: Comment
    let onReply: (() -> Void)?
    
    init(comment: Comment, onReply: (() -> Void)? = nil) {
        self.comment = comment
        self.onReply = onReply
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
                HStack(alignment: .firstTextBaseline) {
                    Text(comment.authorName)
                        .font(.subheadline).bold()
                    Text("• \(comment.timestamp.timeAgoDisplay())")
                        .font(.caption).foregroundColor(.textLight)
                    Spacer()
                }
                
                Text(comment.content)
                    .font(.body)
                
                HStack {
                    Button("Reply") {
                        onReply?()
                    }
                    .font(.caption).bold().foregroundColor(.textLight)
                    .buttonStyle(.plain)
                    
                    if comment.repliesCount > 0 {
                        Button {
                            onReply?()
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


// ... (CommentInputView struct) ...
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
