// File: arafatrahman/myinstructor/MyInstructor-main/MyInstructor/Features/Community/UserListView.swift
// --- UPDATED: Enhanced UserListRow to display profile picture if available ---

import SwiftUI

struct UserListView: View {
    let title: String
    let userIDs: [String]
    
    @EnvironmentObject var dataService: DataService
    @State private var users: [AppUser] = []
    @State private var isLoading = true
    
    var body: some View {
        List {
            if isLoading {
                HStack {
                    Spacer()
                    ProgressView()
                    Spacer()
                }
                .listRowSeparator(.hidden)
            } else if users.isEmpty {
                Text("No users found.")
                    .foregroundColor(.secondary)
            } else {
                ForEach(users) { user in
                    NavigationLink(destination: InstructorPublicProfileView(instructorID: user.id ?? "")) {
                        UserListRow(user: user)
                    }
                }
            }
        }
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await loadUsers()
        }
    }
    
    private func loadUsers() async {
        isLoading = true
        // Fetch users concurrently
        await withTaskGroup(of: AppUser?.self) { group in
            for id in userIDs {
                group.addTask {
                    try? await dataService.fetchUser(withId: id)
                }
            }
            
            var loadedUsers: [AppUser] = []
            for await user in group {
                if let user = user {
                    loadedUsers.append(user)
                }
            }
            // Sort by name
            self.users = loadedUsers.sorted { ($0.name ?? "") < ($1.name ?? "") }
        }
        isLoading = false
    }
}

struct UserListRow: View {
    let user: AppUser
    
    var body: some View {
        HStack(spacing: 12) {
            // Profile Picture Logic
            if let photoURLString = user.photoURL, let url = URL(string: photoURLString) {
                AsyncImage(url: url) { phase in
                    if let image = phase.image {
                        image
                            .resizable()
                            .scaledToFill()
                    } else if phase.error != nil {
                        // Error loading image, show fallback
                        Image(systemName: "person.circle.fill")
                            .resizable()
                            .foregroundColor(.gray)
                    } else {
                        // Loading state
                        ProgressView()
                            .scaleEffect(0.5)
                    }
                }
                .frame(width: 40, height: 40)
                .clipShape(Circle())
                .overlay(Circle().stroke(Color.gray.opacity(0.2), lineWidth: 1))
            } else {
                // Fallback / No URL provided
                Image(systemName: "person.circle.fill")
                    .resizable()
                    .scaledToFit()
                    .foregroundColor(.gray)
                    .frame(width: 40, height: 40)
            }
            
            VStack(alignment: .leading) {
                Text(user.name ?? "User")
                    .font(.headline)
                
                Text(user.role.rawValue.capitalized)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}
