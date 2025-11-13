// File: arafatrahman/myinstructor/MyInstructor-main/MyInstructor/Features/Community/CommunityFeedView.swift
// --- UPDATED: Handles multiple media URLs ---

import SwiftUI

// Flow Item 18: Community Feed
struct CommunityFeedView: View {
    @EnvironmentObject var communityManager: CommunityManager
    @EnvironmentObject var authManager: AuthManager
    
    @State private var posts: [Post] = []
    @State private var searchText = ""
    @State private var filterMode: CommunityFilter = .all
    @State private var isCreatePostPresented = false
    
    @State private var isLoading = true
    
    var filteredPosts: [Post] {
        if searchText.isEmpty {
            return posts
        } else {
            return posts.filter { $0.content?.localizedCaseInsensitiveContains(searchText) ?? false || $0.authorName.localizedCaseInsensitiveContains(searchText) }
        }
    }

    var body: some View {
        NavigationView {
            VStack(spacing: 15) {
                
                // --- *** CUSTOM HEADER *** ---
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
                
                // --- *** "CREATE POST" BAR *** ---
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
                    
                    Button {
                        isCreatePostPresented = true
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
                        .cornerRadius(20)
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
                } else if filteredPosts.isEmpty {
                    EmptyStateView(icon: "message.circle", message: "No posts match your filters. Start a conversation now!")
                } else {
                    List {
                        ForEach(filteredPosts) { post in
                            NavigationLink {
                                PostDetailView(post: post)
                            } label: {
                                PostCard(post: post) // --- PostCard now handles mediaURLs ---
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

// --- *** POSTCARD IS UPDATED TO HANDLE MULTIPLE IMAGES *** ---
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
                    // Show timestamp and location
                    HStack(spacing: 8) {
                        Text(post.timestamp, style: .relative).font(.caption).foregroundColor(.textLight)
                        if let location = post.location {
                            HStack(spacing: 3) {
                                Image(systemName: "mappin.circle.fill")
                                Text(location)
                            }
                            .font(.caption)
                            .foregroundColor(.textLight)
                            .lineLimit(1)
                        }
                    }
                }
                
                Spacer()
                
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
                    .padding(.bottom, 5)
            }
            
            // --- *** UPDATED MEDIA SECTION *** ---
            // Check for media URLs, get the first one
            if let mediaURLs = post.mediaURLs, let firstURLString = mediaURLs.first, let url = URL(string: firstURLString) {
                ZStack(alignment: .topTrailing) {
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .success(let image):
                            image
                                .resizable()
                                .scaledToFit()
                                .cornerRadius(10)
                                .padding(.vertical, 5)
                        case .failure:
                            HStack(spacing: 8) {
                                Image(systemName: "photo.on.rectangle")
                                Text("Failed to load image")
                            }
                            .font(.caption)
                            .foregroundColor(.textLight)
                            .padding(.vertical, 10)
                        case .empty:
                            ProgressView()
                                .frame(maxWidth: .infinity, minHeight: 150, alignment: .center)
                        @unknown default:
                            EmptyView()
                        }
                    }
                    
                    // Add badge if more than 1 image
                    if mediaURLs.count > 1 {
                        Text("1/\(mediaURLs.count)")
                            .font(.caption.bold())
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.black.opacity(0.7))
                            .foregroundColor(.white)
                            .cornerRadius(10)
                            .padding(10)
                    }
                }
            }
            // --- *** END OF MEDIA SECTION *** ---

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
// --- *** END OF UPDATE *** ---

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
