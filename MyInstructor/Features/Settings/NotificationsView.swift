// File: arafatrahman/myinstructor/MyInstructor-main/MyInstructor/Features/Settings/NotificationsView.swift
// --- UPDATED: Re-implemented Student Request section ---

import SwiftUI

// Flow Item 14: Notifications
struct NotificationsView: View {
    @EnvironmentObject var authManager: AuthManager
    @EnvironmentObject var communityManager: CommunityManager // Re-enabled
    
    @State private var notifications: [NotificationGroup] = []
    @State private var requests: [StudentRequest] = [] // Re-enabled
    
    var body: some View {
        NavigationView {
            List {
                // --- STUDENT REQUESTS SECTION (RE-ADDED) ---
                if authManager.role == .instructor && !requests.isEmpty {
                    Section(header: Text("Student Requests").font(.headline).foregroundColor(.accentGreen)) {
                        ForEach(requests) { request in
                            NotificationRequestRow(request: request, onApprove: {
                                Task { await handleRequest(request, approve: true) }
                            }, onDeny: {
                                Task { await handleRequest(request, approve: false) }
                            })
                        }
                        .listRowInsets(EdgeInsets(top: 8, leading: 10, bottom: 8, trailing: 10))
                    }
                }
                
                // --- Regular Notifications ---
                if notifications.isEmpty && requests.isEmpty { // Check both
                    Text("You're all caught up! No new notifications.")
                        .foregroundColor(.textLight)
                        .padding()
                } else if !notifications.isEmpty {
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
            .refreshable { // Add refreshable
                await fetchNotifications()
            }
        }
    }
    
    private func fetchNotifications() async {
        guard let userID = authManager.user?.id else { return }
        
        // 1. Fetch regular notifications (TODO)
        print("Fetching notifications...")
        // self.notifications = ...
        
        // 2. Fetch student requests (Re-enabled)
        if authManager.role == .instructor {
            do {
                self.requests = try await communityManager.fetchRequests(for: userID)
            } catch {
                print("Failed to fetch student requests: \(error)")
            }
        }
    }
    
    // --- ADDED: Function to handle request actions ---
    private func handleRequest(_ request: StudentRequest, approve: Bool) async {
        do {
            if approve {
                try await communityManager.approveRequest(request)
            } else {
                try await communityManager.denyRequest(request)
            }
            // Remove from list on success
            withAnimation {
                requests.removeAll { $0.id == request.id }
            }
        } catch {
            print("Failed to handle request: \(error)")
        }
    }
}

// --- ADDED: Row view for displaying requests ---
// (Based on CompactRequestRow from StudentsListView)
struct NotificationRequestRow: View {
    let request: StudentRequest
    let onApprove: () -> Void
    let onDeny: () -> Void
    
    var body: some View {
        HStack {
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
                Text(request.studentName)
                    .font(.headline)
                Text("Sent \(request.timestamp.formatted(.relative(presentation: .named)))")
                    .font(.caption)
                    .foregroundColor(.textLight)
            }
            
            Spacer()
            
            // Buttons
            HStack(spacing: 8) {
                Button(action: onDeny) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title2)
                        .foregroundColor(.warningRed)
                }
                .buttonStyle(BorderlessButtonStyle())
                
                Button(action: onApprove) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.title2)
                        .foregroundColor(.accentGreen)
                }
                .buttonStyle(BorderlessButtonStyle())
            }
        }
        .padding(10)
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: Color.textDark.opacity(0.05), radius: 5, x: 0, y: 2)
    }
}


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
