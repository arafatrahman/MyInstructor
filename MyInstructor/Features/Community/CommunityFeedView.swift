// File: arafatrahman/myinstructor/MyInstructor-main/MyInstructor/Features/Community/CommunityFeedView.swift
// --- UPDATED: Removed 'Directory' button, added 'Find Instructor' icon link ---

import SwiftUI

// Flow Item 18: Community Feed
struct CommunityFeedView: View {
    @EnvironmentObject var communityManager: CommunityManager
    @EnvironmentObject var authManager: AuthManager
    
    @State private var posts: [Post] = []
    @State private var searchText = ""
    @State private var filterMode: CommunityFilter = .all
    @State private var isCreatePostPresented = false
    
    // --- THIS STATE IS NO LONGER NEEDED ---
    // @State private var isShowingDirectory = false
    
    @State private var isLoading = true
    
    // Simple mock filter for the UI demonstration
    var filteredPosts: [Post] {
        if searchText.isEmpty {
            return posts
        } else {
            return posts.filter { $0.content?.localizedCaseInsensitiveContains(searchText) ?? false || $0.authorName.localizedCaseInsensitiveContains(searchText) }
        }
    }

    var body: some View {
        NavigationView {
            VStack {
                // Top Bar: Search | Filter (All / Instructors / Local / Trending)
                HStack {
                    SearchBar(text: $searchText, placeholder: "Search posts or people")
                    
                    Picker("Filter", selection: $filterMode) {
                        Text("All").tag(CommunityFilter.all)
                        Text("Instructors").tag(CommunityFilter.instructors)
                        Text("Local").tag(CommunityFilter.local)
                    }
                    .pickerStyle(.menu)
                    .frame(width: 110)
                    .foregroundColor(.primaryBlue)
                }
                .padding(.horizontal)
                
                // Content View
                if isLoading {
                    ProgressView("Loading Community...")
                        .padding(.top, 50)
                } else if filteredPosts.isEmpty {
                    EmptyStateView(icon: "message.circle", message: "No posts match your filters. Start a conversation now!")
                } else {
                    List {
                        ForEach(filteredPosts) { post in
                            NavigationLink {
                                PostDetailView(post: post) // Navigate to Flow 20
                            } label: {
                                PostCard(post: post)
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
            .navigationTitle("Community")
            .toolbar {
                // --- THIS LEADING BUTTON HAS BEEN REMOVED ---
                // ToolbarItem(placement: .navigationBarLeading) {
                //    Button("Directory") {
                //        isShowingDirectory = true // Navigate to Flow 21
                //    }
                //    .foregroundColor(.primaryBlue)
                // }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    HStack {
                        // --- *** NEW "FIND INSTRUCTOR" BUTTON *** ---
                        // Show "Find Instructor" button ONLY for students
                        if authManager.role == .student {
                            NavigationLink(destination: InstructorDirectoryView()) {
                                Image(systemName: "person.badge.plus.fill")
                                    .font(.title2)
                                    .foregroundColor(.primaryBlue)
                            }
                        }
                        // --- *** END OF NEW BUTTON *** ---

                        // Floating Button: “+” → Create Post
                        Button {
                            isCreatePostPresented = true // Navigate to Flow 19
                        } label: {
                            Image(systemName: "square.and.pencil")
                                .font(.title2)
                        }
                    }
                }
            }
            .task { await fetchPosts() }
            .sheet(isPresented: $isCreatePostPresented) {
                CreatePostView(onPostCreated: { Task { await fetchPosts() } })
            }
            // --- THIS SHEET IS NO LONGER NEEDED ---
            // .sheet(isPresented: $isShowingDirectory) {
            //    InstructorDirectoryView()
            // }
        }
        .navigationViewStyle(.stack) // Add this for correct navigation
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
}

enum CommunityFilter: String {
    case all, instructors, local, trending
}

// Post Card (Flow Item 18 detail)
struct PostCard: View {
    let post: Post
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Avatar + name + Timestamp
            HStack(alignment: .top) {
                Image(systemName: post.authorRole == .instructor ? "person.fill.viewfinder" : "person.crop.circle")
                    .foregroundColor(post.authorRole == .instructor ? .primaryBlue : .accentGreen)
                    .font(.title)
                
                VStack(alignment: .leading) {
                    HStack {
                        Text(post.authorName).font(.headline)
                        if post.authorRole == .instructor {
                            Text("Instructor").font(.caption).bold().foregroundColor(.white).padding(4).background(Color.primaryBlue).cornerRadius(4)
                        }
                    }
                    Text(post.timestamp, style: .relative).font(.caption).foregroundColor(.textLight)
                }
                
                Spacer()
                
                // Action Button
                if post.authorRole == .instructor {
                    Button("Book") { print("Booking instructor...") }
                        .buttonStyle(.borderedProminent)
                        .tint(.accentGreen)
                }
            }
            
            // Content
            if let content = post.content {
                Text(content)
                    .font(.body)
            }
            
            // Placeholder for media/Progress Update (Media not fully implemented)
            if post.postType == .progressUpdate {
                Text("📈 Progress Update: 65% Mastery Achieved!")
                    .font(.subheadline).bold()
                    .foregroundColor(.primaryBlue)
                    .padding(5)
                    .background(Color.secondaryGray)
                    .cornerRadius(5)
            }
            
            Divider()
            
            // Reactions row + Comment count
            HStack {
                ReactionButton(icon: "hand.thumbsup.fill", count: post.reactionsCount["thumbsup"] ?? 0)
                ReactionButton(icon: "flame.fill", count: post.reactionsCount["fire"] ?? 0, color: .orange)
                ReactionButton(icon: "heart.fill", count: post.reactionsCount["heart"] ?? 0, color: .warningRed)
                
                Spacer()
                
                Text("\(post.commentsCount) Comments")
                    .font(.caption)
                    .foregroundColor(.textLight)
            }
        }
        .padding(15)
        .background(Color(.systemBackground))
        .cornerRadius(15)
        .shadow(color: Color.textDark.opacity(0.1), radius: 8, x: 0, y: 4)
    }
}

struct ReactionButton: View {
    let icon: String
    let count: Int
    var color: Color = .primaryBlue
    
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .foregroundColor(color)
            Text("\(count)")
                .font(.subheadline)
                .foregroundColor(.textDark)
        }
        .padding(.trailing, 10)
    }
}
