// File: arafatrahman/myinstructor/MyInstructor-main/MyInstructor/Features/Community/CommunityFeedView.swift
// --- UPDATED: Replaced SearchBar/Toolbar with a custom header to match user's image ---

import SwiftUI

// Flow Item 18: Community Feed
struct CommunityFeedView: View {
    @EnvironmentObject var communityManager: CommunityManager
    @EnvironmentObject var authManager: AuthManager
    
    @State private var posts: [Post] = []
    @State private var searchText = "" // This is no longer used by a SearchBar, but kept for filtering logic
    @State private var filterMode: CommunityFilter = .all // Filter logic is still present
    @State private var isCreatePostPresented = false
    
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
            VStack(spacing: 15) { // Added spacing
                
                // --- *** NEW CUSTOM HEADER *** ---
                HStack {
                    Text("Community Hub")
                        .font(.largeTitle).bold()
                        .foregroundColor(.textDark)
                    
                    Spacer()
                    
                    // 1. Search Button
                    Button {
                        // TODO: Implement search (e.g., show a search bar or modal)
                        print("Search tapped")
                    } label: {
                        Image(systemName: "magnifyingglass")
                            .font(.title2)
                            .foregroundColor(.textDark)
                    }
                    .padding(.trailing, 5)
                    
                    // 2. "Find Instructor" (from old toolbar)
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
                // --- *** END CUSTOM HEADER *** ---

                
                // --- *** NEW "CREATE POST" BAR *** ---
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
                    
                    // This Button looks like text and triggers the sheet
                    Button {
                        isCreatePostPresented = true // Open create post screen
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
                    
                    // This "Photo" Button also triggers the sheet
                    Button {
                        isCreatePostPresented = true // Open create post screen
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "photo.fill")
                            Text("Photo")
                        }
                        .font(.subheadline).bold()
                        .padding(.horizontal, 10)
                        .padding(.vertical, 8)
                        .background(Color.accentGreen)
                        .foregroundColor(.white)
                        .cornerRadius(20) // Pill shape
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color(.systemGray6)) // Light background
                .cornerRadius(30) // Rounded bar
                .padding(.horizontal) // Inset the bar
                // --- *** END "CREATE POST" BAR *** ---
                
                
                // --- THIS HSTACK WAS REMOVED ---
                // HStack {
                //    SearchBar(text: $searchText, placeholder: "Search posts or people")
                //    Picker("Filter", ...)
                // }
                // .padding(.horizontal)
                
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
            // .navigationTitle("Community") // <-- REMOVED
            .navigationBarHidden(true) // <-- ADDED
            // --- .toolbar modifier was here, but is now removed ---
            .task { await fetchPosts() }
            .sheet(isPresented: $isCreatePostPresented) {
                CreatePostView(onPostCreated: { Task { await fetchPosts() } })
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
