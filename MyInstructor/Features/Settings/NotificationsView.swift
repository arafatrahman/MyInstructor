import SwiftUI

struct NotificationsView: View {
    @EnvironmentObject var authManager: AuthManager
    @EnvironmentObject var communityManager: CommunityManager
    @EnvironmentObject var notificationManager: NotificationManager
    
    @State private var pendingRequests: [StudentRequest] = []
    
    var body: some View {
        List {
            // --- REQUESTS SECTION (For Instructors) ---
            if authManager.role == .instructor && !pendingRequests.isEmpty {
                Section(header: Text("Student Requests")) {
                    ForEach(pendingRequests) { request in
                        NotificationRequestRow(request: request, onApprove: {
                            Task { await handleRequest(request, approve: true) }
                        }, onDeny: {
                            Task { await handleRequest(request, approve: false) }
                        })
                    }
                }
            }
            
            // --- ALERTS SECTION (Live Data) ---
            if notificationManager.notifications.isEmpty && pendingRequests.isEmpty {
                // Empty State
                VStack(spacing: 15) {
                    Spacer()
                    Image(systemName: "bell.slash")
                        .font(.largeTitle)
                        .foregroundColor(.secondary)
                    Text("You're all caught up! No new notifications.")
                        .font(.headline)
                        .foregroundColor(.secondary)
                    Spacer()
                }
                .frame(maxWidth: .infinity)
                .listRowBackground(Color.clear)
                
            } else if !notificationManager.notifications.isEmpty {
                // List of Notifications
                Section(header: Text("Recent Updates")) {
                    ForEach(notificationManager.notifications) { item in
                        AppNotificationRow(item: item)
                            .listRowBackground(item.isRead ? Color(.systemBackground) : Color.blue.opacity(0.05))
                    }
                }
            }
        }
        .navigationTitle("Notifications")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if !notificationManager.notifications.isEmpty {
                Button("Mark All Read") {
                    if let uid = authManager.user?.id {
                        notificationManager.markAllAsRead(userID: uid)
                    }
                }
            }
        }
        .task {
            // Instructor-specific check for requests
            if let uid = authManager.user?.id, authManager.role == .instructor {
                self.pendingRequests = (try? await communityManager.fetchRequests(for: uid)) ?? []
            }
        }
    }
    
    private func handleRequest(_ request: StudentRequest, approve: Bool) async {
        do {
            if approve { try await communityManager.approveRequest(request) }
            else { try await communityManager.denyRequest(request) }
            
            if let uid = authManager.user?.id {
                self.pendingRequests = (try? await communityManager.fetchRequests(for: uid)) ?? []
            }
        } catch { print("Error: \(error)") }
    }
}

// --- Helper Rows ---

struct AppNotificationRow: View {
    let item: AppNotification
    
    var iconName: String {
        switch item.type {
        case "lesson": return "calendar"
        case "progress": return "chart.bar.fill"
        case "note": return "note.text"
        // --- NEW ICONS ---
        case "reaction": return "heart.fill"
        case "comment": return "bubble.left.fill"
        case "reply": return "arrowshape.turn.up.left.fill"
        // ----------------
        default: return "bell.fill"
        }
    }
    
    var iconColor: Color {
        switch item.type {
        case "lesson": return .accentGreen
        case "progress": return .primaryBlue
        case "note": return .orange
        // --- NEW COLORS ---
        case "reaction": return .red
        case "comment", "reply": return .primaryBlue
        // ------------------
        default: return .gray
        }
    }
    
    var body: some View {
        HStack(alignment: .top) {
            Image(systemName: iconName)
                .foregroundColor(iconColor)
                .font(.title3)
                .frame(width: 30)
                .padding(.top, 2)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(item.title).font(.headline).foregroundColor(item.isRead ? .primary : .primary)
                Text(item.message).font(.subheadline).foregroundColor(.secondary)
                Text(item.timestamp.formatted(.relative(presentation: .named)))
                    .font(.caption).foregroundColor(.gray)
            }
            
            if !item.isRead {
                Spacer()
                Circle().fill(Color.blue).frame(width: 8, height: 8).padding(.top, 5)
            }
        }
        .padding(.vertical, 4)
    }
}

struct NotificationRequestRow: View {
    let request: StudentRequest
    let onApprove: () -> Void
    let onDeny: () -> Void
    var body: some View {
        HStack {
            VStack(alignment: .leading) {
                Text(request.studentName).font(.headline)
                Text("Sent \(request.timestamp.formatted(.relative(presentation: .named)))").font(.caption).foregroundColor(.gray)
            }
            Spacer()
            HStack {
                Button(action: onDeny) { Image(systemName: "xmark.circle.fill").foregroundColor(.red).font(.title2) }.buttonStyle(.plain)
                Button(action: onApprove) { Image(systemName: "checkmark.circle.fill").foregroundColor(.green).font(.title2) }.buttonStyle(.plain)
            }
        }
    }
}
