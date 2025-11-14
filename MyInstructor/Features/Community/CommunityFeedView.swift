// File: arafatrahman/myinstructor/MyInstructor-main/MyInstructor/Features/Community/CommunityFeedView.swift
// --- UPDATED: PostCard completely redesigned as requested ---

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
                            // NavigationLink removed from here to allow tapping on carousel
                            VStack {
                                PostCard(post: post)
                                NavigationLink(destination: PostDetailView(post: post)) {
                                    // This is an invisible link overlay on the non-image parts
                                    EmptyView()
                                }
                                .opacity(0)
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

// --- *** POSTCARD IS HEAVILY UPDATED *** ---
struct PostCard: View {
    let post: Post
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Avatar + name + Timestamp
            HStack(alignment: .top) {
                // 1. Author's Profile Photo
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
                    
                    // 2. Stacked Time and Location
                    VStack(alignment: .leading, spacing: 2) {
                        Text(post.timestamp, style: .relative).font(.caption).foregroundColor(.textLight)
                        if let location = post.location, !location.isEmpty {
                            HStack(spacing: 3) {
                                Image(systemName: "mappin.circle.fill")
                                Text(location)
                            }
                            .font(.caption)
                            .foregroundColor(.textLight)
                            .lineLimit(1)
                        }
                    }
                    // 3. Instructor badge is REMOVED
                }
                
                Spacer()
                
                // 4. "Follow" Button
                Button("Follow") {
                    print("Following user \(post.authorID)...")
                    // TODO: Add follow logic
                }
                .buttonStyle(.bordered)
                .tint(.primaryBlue)
                .font(.caption.bold())
            }
            
            // Content
            if let content = post.content {
                Text(content)
                    .font(.body)
                    .padding(.bottom, 5)
            }
            
            // --- *** 5. SWIPEABLE IMAGE CAROUSEL *** ---
            if let mediaURLs = post.mediaURLs, !mediaURLs.isEmpty {
                TabView {
                    ForEach(mediaURLs, id: \.self) { urlString in
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
                                        .frame(maxWidth: .infinity, alignment: .center)
                                @unknown default:
                                    EmptyView()
                                }
                            }
                        }
                    }
                }
                .frame(height: 350) // Give the carousel a fixed height
                .tabViewStyle(.page(indexDisplayMode: .automatic))
                .cornerRadius(10)
                .padding(.vertical, 5)
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
