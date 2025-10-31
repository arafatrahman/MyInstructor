// File: arafatrahman/myinstructor/MyInstructor-main/MyInstructor/Common/Views/DashboardHeader.swift
// --- THIS IS THE CORRECT, CLEAN FILE ---

import SwiftUI

// Shared Header for Instructor and Student Dashboards (Flow 5 & 6)
struct DashboardHeader: View {
    @EnvironmentObject var authManager: AuthManager

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
            
            // "Find Instructor" button ONLY for students
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

            // --- NEW MESSAGES BUTTON ---
            NavigationLink(destination: MessagingView()) {
                ZStack {
                    Image(systemName: "message.fill")
                        .font(.title2)
                        .foregroundColor(.textDark)
                    
                    // TODO: Add a badge for unread messages
                }
            }
            .padding(.trailing, 10) // Add some spacing
            // --- END OF NEW BUTTON ---

            // Notifications Bell (Flow 14)
            NavigationLink(destination: NotificationsView()) {
                ZStack {
                    Image(systemName: "bell.fill")
                        .font(.title2)
                        .foregroundColor(.textDark)

                    // Placeholder for badge count
                    Circle()
                        .fill(Color.warningRed)
                        .frame(width: 10, height: 10)
                        .offset(x: 8, y: -8)
                        .opacity(3 > 0 ? 1 : 0) // Example: Show badge if count > 0
                }
            }
            .padding(.trailing, 10) // Add some spacing

            // --- Profile Avatar/Settings (Flow 15 - Updated) ---
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
