// File: arafatrahman/myinstructor/MyInstructor-main/MyInstructor/Features/Settings/NotificationsView.swift
// --- UPDATED: Now fetches ALL requests (pending, denied, blocked) to show as notifications ---

import SwiftUI

// Flow Item 14: Notifications
struct NotificationsView: View {
    @EnvironmentObject var authManager: AuthManager
    @EnvironmentObject var communityManager: CommunityManager
    
    @State private var notifications: [NotificationGroup] = [] // For non-request alerts
    
    // --- UPDATED: State for all request types ---
    @State private var pendingRequests: [StudentRequest] = []
    @State private var deniedRequests: [StudentRequest] = []
    @State private var blockedRequests: [StudentRequest] = []
    
    // Check for any unread non-request notifications
    private var hasUnreadNotifications: Bool {
        notifications.flatMap { $0.items }.contains { !$0.isRead }
    }
    
    // Check if there are any request notifications
    private var hasAnyRequests: Bool {
        !pendingRequests.isEmpty || !deniedRequests.isEmpty || !blockedRequests.isEmpty
    }
    
    var body: some View {
        List {
            // --- STUDENT REQUESTS SECTION ---
            
            // Pending
            if authManager.role == .instructor && !pendingRequests.isEmpty {
                Section(header: Text("Student Requests").font(.headline).foregroundColor(.accentGreen)) {
                    ForEach(pendingRequests) { request in
                        NotificationRequestRow(request: request, onApprove: {
                            Task { await handleRequest(request, approve: true) }
                        }, onDeny: {
                            Task { await handleRequest(request, approve: false) }
                        })
                    }
                    .listRowInsets(EdgeInsets(top: 8, leading: 10, bottom: 8, trailing: 10))
                }
            }
            
            // --- STUDENT-FACING NOTIFICATIONS ---
            
            // Denied
            if authManager.role == .student && !deniedRequests.isEmpty {
                Section(header: Text("Updates").font(.headline).foregroundColor(.warningRed)) {
                    ForEach(deniedRequests) { request in
                        // Show a row without buttons
                        NotificationInfoRow(request: request)
                    }
                }
            }
            
            // Blocked
            if authManager.role == .student && !blockedRequests.isEmpty {
                Section(header: Text("Blocked by Instructor").font(.headline).foregroundColor(.black)) {
                    ForEach(blockedRequests) { request in
                        // Show a row without buttons
                        NotificationInfoRow(request: request)
                    }
                }
            }
            
            // --- Regular Notifications ---
            if notifications.isEmpty && !hasAnyRequests {
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
        .navigationBarTitleDisplayMode(.inline)
        .listStyle(.insetGrouped)
        .toolbar {
            Button("Mark All Read") {
                withAnimation {
                    markAllAsRead()
                }
            }
            .foregroundColor(.primaryBlue)
            // Mark all read should only be active for non-request notifications
            .disabled(!hasUnreadNotifications)
        }
        .task {
            await fetchNotifications()
        }
        .refreshable {
            await fetchNotifications()
        }
    }
    
    private func fetchNotifications() async {
        guard let userID = authManager.user?.id else { return }
        
        // 1. Fetch regular notifications (TODO)
        print("Fetching notifications...")
        // self.notifications = ...
        
        // 2. Fetch requests based on role
        if authManager.role == .instructor {
            // Instructors only see PENDING requests here
            do {
                self.pendingRequests = try await communityManager.fetchRequests(for: userID)
            } catch {
                print("Failed to fetch student requests: \(error)")
            }
        } else {
            // Students see DENIED and BLOCKED requests here
            do {
                let allSentRequests = try await communityManager.fetchSentRequests(for: userID)
                self.deniedRequests = allSentRequests.filter { $0.status == .denied }
                self.blockedRequests = allSentRequests.filter { $0.status == .blocked }
            } catch {
                print("Failed to fetch student's sent requests: \(error)")
            }
        }
    }
    
    // --- (This function is for INSTRUCTORS) ---
    private func handleRequest(_ request: StudentRequest, approve: Bool) async {
        do {
            if approve {
                try await communityManager.approveRequest(request)
            } else {
                try await communityManager.denyRequest(request)
            }
            // Remove from list on success
            withAnimation {
                pendingRequests.removeAll { $0.id == request.id }
            }
        } catch {
            print("Failed to handle request: \(error)")
        }
    }
    
    private func markAllAsRead() {
        for groupIndex in notifications.indices {
            for itemIndex in notifications[groupIndex].items.indices {
                notifications[groupIndex].items[itemIndex].isRead = true
            }
        }
    }
}

// --- Row for INSTRUCTORS (with buttons) ---
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

// --- *** NEW ROW for STUDENTS (no buttons) *** ---
struct NotificationInfoRow: View {
    @EnvironmentObject var dataService: DataService
    let request: StudentRequest
    
    @State private var instructorName: String = "Instructor"
    
    var body: some View {
        HStack {
            VStack(alignment: .leading) {
                Text(instructorName)
                    .font(.headline)
                Text(request.status == .denied ? "Your request was denied." : "You have been blocked by this instructor.")
                    .font(.subheadline)
                    .foregroundColor(request.status == .denied ? .warningRed : .black)
                Text(request.timestamp, style: .date)
                    .font(.caption)
                    .foregroundColor(.textLight)
            }
            
            Spacer()
            
            StatusBadge(status: request.status)
        }
        .padding(.vertical, 6)
        .task {
            // Fetch the instructor's name
            if let user = try? await dataService.fetchUser(withId: request.instructorID) {
                self.instructorName = user.name ?? "Instructor"
            }
        }
    }
}
// --- *** END OF NEW ROW *** ---


struct NotificationGroup: Identifiable {
    let id = UUID()
    let type: String
    var items: [NotificationItem]
}

struct NotificationItem: Identifiable, Hashable {
    let id = UUID()
    let message: String
    var isRead: Bool
    
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
