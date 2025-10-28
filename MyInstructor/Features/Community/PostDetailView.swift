import SwiftUI

// Flow Item 20: Post Detail
struct PostDetailView: View {
    let post: Post // The post being viewed
    
    @State private var commentText: String = ""
    @State private var isReportFlowPresented = false
    
    // Removed mock comments
    @State private var comments: [Comment] = []
    
    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 15) {
                    
                    // Post Card Content (Full post details)
                    PostCard(post: post)
                    
                    // Reactions Summary
                    HStack {
                        // Display total reaction count
                        Text("\(post.reactionsCount.values.reduce(0, +)) Reactions")
                            .font(.subheadline).bold()
                        Spacer()
                        // Tappable reaction buttons (for adding a reaction)
                        ReactionActionButton(icon: "hand.thumbsup", count: post.reactionsCount["thumbsup"] ?? 0, color: .primaryBlue)
                        ReactionActionButton(icon: "flame", count: post.reactionsCount["fire"] ?? 0, color: .orange)
                        ReactionActionButton(icon: "heart", count: post.reactionsCount["heart"] ?? 0, color: .warningRed)
                    }
                    .padding(.horizontal)
                    
                    Divider()
                    
                    // Comments Section
                    Text("Comments (\(comments.count))")
                        .font(.headline)
                        .padding(.horizontal)
                    
                    VStack(alignment: .leading, spacing: 20) {
                        if comments.isEmpty {
                            Text("No comments yet.")
                                .foregroundColor(.textLight)
                                .padding(.top, 10)
                        } else {
                            ForEach(comments) { comment in
                                CommentRow(comment: comment)
                            }
                        }
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 20)
                }
            }
            
            // Bottom Actions: Comment box, Save, Share, Report
            Divider()
            CommentInputView(commentText: $commentText, isReportFlowPresented: $isReportFlowPresented)
        }
        .navigationTitle("Post Detail")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $isReportFlowPresented) {
            ReportFlowView() // Flow Item 25
        }
        .task {
            await fetchComments()
        }
    }
    
    private func fetchComments() async {
        // TODO: Add call to a
        // 'communityManager.fetchComments(for: post.id)'
        // and update the 'comments' state.
        print("Fetching comments for post \(post.id ?? "N/A")")
    }
}

// Helper: Reaction Action Button
struct ReactionActionButton: View {
    let icon: String
    let count: Int
    var color: Color
    
    var body: some View {
        Button { // <--- Standard Button action closure
            // TODO: Implement toggle reaction logic
            print("Reacted with \(icon)")
        } label: { // <--- Standard Button label closure
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
    }
}
// Helper: Comment Row
struct CommentRow: View {
    let comment: Comment
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .firstTextBaseline) {
                Text(comment.authorName)
                    .font(.subheadline).bold()
                Text("• \(comment.timestamp, style: .relative)")
                    .font(.caption).foregroundColor(.textLight)
                Spacer()
            }
            Text(comment.content)
                .font(.body)
            
            HStack {
                Button("Reply") { /* ... */ }.font(.caption).foregroundColor(.primaryBlue)
                if comment.repliesCount > 0 {
                    Text("View \(comment.repliesCount) replies")
                        .font(.caption).foregroundColor(.textLight)
                }
            }
        }
    }
}

// Helper: Comment Input and More Menu
struct CommentInputView: View {
    @Binding var commentText: String
    @Binding var isReportFlowPresented: Bool
    
    var body: some View {
        HStack {
            TextField("Add a comment...", text: $commentText)
                .padding(10)
                .background(Color.secondaryGray)
                .cornerRadius(20)
            
            Button("Post") {
                // TODO: Add comment action
                commentText = ""
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
