// File: arafatrahman/myinstructor/MyInstructor-main/MyInstructor/Common/Views/DashboardHeader.swift
// --- UPDATED: With correct logic for unread message dot ---

import SwiftUI

// Shared Header for Instructor and Student Dashboards (Flow 5 & 6)
struct DashboardHeader: View {
    @EnvironmentObject var authManager: AuthManager
    @EnvironmentObject var chatManager: ChatManager

    let notificationCount: Int // This view now requires a count

    var userName: String {
        authManager.user?.name ?? (authManager.role == .instructor ? "Instructor" : "Student")
    }

    // Computed property for the profile image URL
    private var profileImageURL: URL? {
        guard let urlString = authManager.user?.photoURL, !urlString.isEmpty else {
            return nil
        }
        return URL(string: urlString)
    }
    
    // --- *** THIS LOGIC IS NOW CORRECT *** ---
    private var hasUnreadMessages: Bool {
        guard let currentUserID = authManager.user?.id else { return false }
        
        // Check if there is any conversation where:
        // 1. There are unread messages (count > 0)
        // 2. The last message was NOT sent by the current user
        return chatManager.conversations.contains { convo in
            return convo.unreadCount > 0 && convo.lastMessageSenderID != currentUserID
        }
    }

    var body: some View {
        HStack {
            // Welcome Text
            VStack(alignment: .leading) {
                Text("Welcome Back,")
                    .font(.callout)
                    .foregroundColor(.textLight)
                Text(userName)
                    .font(.title2).bold()
                    .foregroundColor(.textDark)
            }

            Spacer()
            
            // Show "Find Instructor" button ONLY for students
            if authManager.role == .student {
                NavigationLink(destination: InstructorDirectoryView()) {
                    ZStack {
                        Image(systemName: "person.badge.plus.fill")
                            .font(.title2)
                            .foregroundColor(.textDark)
                    }
                    .padding(.trailing, 8) // Add spacing between this and the bell
                }
            }

            // Messages Button
            NavigationLink(destination: MessagingView()) {
                ZStack {
                    Image(systemName: "message.fill")
                        .font(.title2)
                        .foregroundColor(.textDark)
                    
                    // Unread Message Badge
                    Circle()
                        .fill(Color.blue) // Standard blue for "unread"
                        .frame(width: 10, height: 10)
                        .offset(x: 10, y: -10) // Adjusted offset for this icon
                        .opacity(hasUnreadMessages ? 1 : 0)
                        .animation(.spring(), value: hasUnreadMessages) // Animate badge
                }
            }
            .padding(.trailing, 10) // Add some spacing

            // Notifications Bell (Flow 14)
            NavigationLink(destination: NotificationsView()) {
                ZStack {
                    Image(systemName: "bell.fill")
                        .font(.title2)
                        .foregroundColor(.textDark)

                    // Notification Badge
                    Circle()
                        .fill(Color.warningRed)
                        .frame(width: 10, height: 10)
                        .offset(x: 8, y: -8)
                        .opacity(notificationCount > 0 ? 1 : 0) // Use the real count
                        .animation(.spring(), value: notificationCount > 0) // Animate badge
                }
            }
            .padding(.trailing, 10) // Add some spacing

            // Profile Avatar/Settings
            NavigationLink(destination: UserProfileView()) {
                if let url = profileImageURL {
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .empty:
                            ProgressView()
                                .frame(width: 35, height: 35)
                        case .success(let image):
                            image
                                .resizable()
                                .scaledToFill() // Fill the circle frame
                                .frame(width: 35, height: 35)
                                .clipShape(Circle()) // Make it circular
                                .overlay(Circle().stroke(Color.primaryBlue.opacity(0.3), lineWidth: 1)) // Optional border
                        case .failure:
                            Image(systemName: "person.crop.circle.fill")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 35, height: 35)
                                .foregroundColor(.primaryBlue) // Use accent color for fallback
                        @unknown default:
                            Image(systemName: "person.crop.circle.fill")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 35, height: 35)
                                .foregroundColor(.primaryBlue)
                        }
                    }
                } else {
                    Image(systemName: "person.crop.circle.fill")
                        .resizable()
                        .scaledToFit() // Use scaledToFit for system icons
                        .frame(width: 35, height: 35)
                        .foregroundColor(.primaryBlue)
                }
            }
        }
        .padding(.horizontal)
        .padding(.top, 10) // Adjust top padding as needed for safe area
    }
}
