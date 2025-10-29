// File: arafatrahman/myinstructor/MyInstructor-main/MyInstructor/Features/Settings/NotificationsView.swift
import SwiftUI

// Flow Item 14: Notifications
struct NotificationsView: View {
    @EnvironmentObject var authManager: AuthManager
    @EnvironmentObject var communityManager: CommunityManager // <-- ADDED
    
    @State private var notifications: [NotificationGroup] = []
    @State private var requests: [StudentRequest] = [] // <-- ADDED
    
    var body: some View {
        NavigationView {
            List {
                // --- *** NEW SECTION FOR REQUESTS *** ---
                if !requests.isEmpty {
                    Section(header: Text("Student Requests").font(.headline).foregroundColor(.accentGreen)) {
                        ForEach(requests) { request in
                            RequestRow(request: request, onApprove: {
                                Task {
                                    try? await communityManager.approveRequest(request)
                                    await fetchNotifications() // Refresh list
                                }
                            }, onDeny: {
                                Task {
                                    try? await communityManager.denyRequest(request)
                                    await fetchNotifications() // Refresh list
                                }
                            })
                        }
                    }
                }
                // --- *** END NEW SECTION *** ---
                
                if notifications.isEmpty && requests.isEmpty { // <-- UPDATED CHECK
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
        
        // 2. Fetch pending student requests (--- ADDED ---)
        do {
            self.requests = try await communityManager.fetchRequests(for: userID)
        } catch {
            print("Failed to fetch requests: \(error)")
            self.requests = []
        }
    }
}

// --- *** ADD THIS NEW SUPPORTING VIEW *** ---
struct RequestRow: View {
    let request: StudentRequest
    let onApprove: () -> Void
    let onDeny: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                // Use AsyncImage for the student's photo
                AsyncImage(url: URL(string: request.studentPhotoURL ?? "")) { phase in
                    if let image = phase.image {
                        image.resizable().scaledToFill()
                    } else {
                        Image(systemName: "person.circle.fill")
                            .resizable()
                            .foregroundColor(.primaryBlue)
                    }
                }
                .frame(width: 45, height: 45)
                .clipShape(Circle())
                
                VStack(alignment: .leading) {
                    Text(request.studentName).font(.headline)
                    Text("Sent \(request.timestamp.formatted(.relative(presentation: .named)))")
                        .font(.caption)
                        .foregroundColor(.textLight)
                }
                Spacer()
            }
            Text("\"I would like to request you as my instructor.\"")
                .font(.subheadline)
                .italic()
                
            HStack(spacing: 10) {
                Button("Deny", role: .destructive, action: onDeny)
                    .buttonStyle(.secondaryDrivingApp)
                    .frame(maxWidth: .infinity)
                    
                Button("Approve", action: onApprove)
                    .buttonStyle(.primaryDrivingApp)
                    .frame(maxWidth: .infinity)
            }
        }
        .padding(.vertical, 8)
    }
}
// --- *** END NEW VIEW *** ---


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
