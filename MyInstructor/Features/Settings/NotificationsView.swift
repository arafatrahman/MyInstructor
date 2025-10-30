// File: arafatrahman/myinstructor/MyInstructor-main/MyInstructor/Features/Settings/NotificationsView.swift
// --- UPDATED: Removed Student Request section ---

import SwiftUI

// Flow Item 14: Notifications
struct NotificationsView: View {
    @EnvironmentObject var authManager: AuthManager
    // @EnvironmentObject var communityManager: CommunityManager // No longer needed here
    
    @State private var notifications: [NotificationGroup] = []
    // @State private var requests: [StudentRequest] = [] // Requests are now in StudentsListView
    
    var body: some View {
        NavigationView {
            List {
                // --- STUDENT REQUESTS SECTION HAS BEEN REMOVED ---
                
                if notifications.isEmpty {
                    Text("You're all caught up! No new notifications.")
                        .foregroundColor(.textLight)
                        .padding()
                } else {
                    ForEach(notifications) { group in
                        Section(header: Text(group.type).font(.headline).foregroundColor(.primaryBlue)) {
                            ForEach(group.items) { item in
                                NotificationRow(item: item)
                                    .listRowBackground(item.isRead ? Color(.systemBackground) : Color.primaryBlue.opacity(0.05))
                            }
                        }
                    }
                }
            }
            .navigationTitle("Notifications")
            .listStyle(.insetGrouped)
            .toolbar {
                Button("Mark All Read") {
                    // TODO: Implement Mark All Read logic
                    print("Notifications marked as read.")
                }
                .foregroundColor(.primaryBlue)
            }
            .task {
                await fetchNotifications()
            }
        }
    }
    
    private func fetchNotifications() async {
        guard let userID = authManager.user?.id else { return }
        
        // 1. Fetch regular notifications (TODO)
        print("Fetching notifications...")
        // self.notifications = ...
        
        // 2. Fetching student requests is no longer done here.
    }
}

// --- RequestRow has been moved to StudentsListView ---

struct NotificationGroup: Identifiable {
    let id = UUID()
    let type: String
    let items: [NotificationItem]
}

struct NotificationItem: Identifiable {
    let id = UUID()
    let message: String
    var isRead: Bool
    
    // TODO: This should come from the data model
    var timeAgo: String {
        let times = ["5m ago", "1h ago", "3d ago", "Yesterday"]
        return times.randomElement()!
    }
}

struct NotificationRow: View {
    let item: NotificationItem
    
    var body: some View {
        HStack(alignment: .top) {
            Image(systemName: item.isRead ? "circle" : "circle.fill")
                .font(.caption)
                .foregroundColor(.primaryBlue)
                .padding(.top, 4)
            
            VStack(alignment: .leading, spacing: 4) {
                // Use AttributedString for bolding names/keywords (like **Emma**)
                Text(.init(item.message))
                    .font(.body)
                    .foregroundColor(item.isRead ? .textLight : .textDark)
                Text(item.timeAgo)
                    .font(.caption)
                    .foregroundColor(.textLight)
            }
            Spacer()
        }
        .padding(.vertical, 5)
    }
}
