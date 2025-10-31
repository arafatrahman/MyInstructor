// File: arafatrahman/myinstructor/MyInstructor-main/MyInstructor/Features/Settings/MessagingView.swift
// --- FULL REDESIGN: Fixes compiler errors and implements new UI ---

import SwiftUI
import Combine

// This is a "normalized" model so we can show
// either Students or Instructors in the same list.
struct ChatContact: Identifiable, Hashable {
    let id: String
    let name: String
    let photoURL: String?
    let userRole: UserRole
    
    let appUser: AppUser
    
    // Manually conform to Hashable and Equatable
    static func == (lhs: ChatContact, rhs: ChatContact) -> Bool {
        lhs.id == rhs.id
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

struct MessagingView: View {
    @EnvironmentObject var authManager: AuthManager
    @EnvironmentObject var dataService: DataService
    
    @State private var contacts: [ChatContact] = []
    @State private var isLoading = true
    
    var body: some View {
        // --- THIS FIXES THE "TWO BACK BUTTONS" BUG ---
        // The NavigationView is removed from here.
        // It's already provided by the Dashboard.
        List {
            if isLoading {
                ProgressView()
            } else if contacts.isEmpty {
                Text(authManager.user?.role == .instructor ? "No approved students yet." : "No approved instructors yet.")
                    .foregroundColor(.textLight)
                    .padding()
            } else {
                ForEach(contacts) { contact in
                    NavigationLink {
                        // Go to the loading view first
                        ChatLoadingView(otherUser: contact.appUser)
                    } label: {
                        ChatContactRow(contact: contact)
                    }
                }
            }
        }
        .listStyle(.plain)
        .navigationTitle("Start a Chat")
        .task {
            await fetchContacts()
        }
    }
    
    func fetchContacts() async {
        guard let user = authManager.user, let userID = user.id else { return }
        isLoading = true
        
        do {
            var fetchedContacts: [ChatContact] = []
            
            if user.role == .instructor {
                // Instructors see their list of Students
                let students = try await dataService.fetchStudents(for: userID)
                fetchedContacts = students.map { student in
                    var appUser = AppUser(id: student.id ?? "", email: student.email, name: student.name, role: .student)
                    appUser.photoURL = student.photoURL
                    return ChatContact(id: student.id ?? "", name: student.name, photoURL: student.photoURL, userRole: .student, appUser: appUser)
                }
                
            } else if user.role == .student {
                // Students see their list of Instructors
                let instructors = try await dataService.fetchInstructors(for: userID)
                fetchedContacts = instructors.map { instructor in
                    ChatContact(id: instructor.id ?? "", name: instructor.name ?? "Instructor", photoURL: instructor.photoURL, userRole: .instructor, appUser: instructor)
                }
            }
            self.contacts = fetchedContacts
        } catch {
            print("Failed to fetch contacts: \(error.localizedDescription)")
        }
        isLoading = false
    }
}

// Renamed to ChatContactRow to avoid compiler error
struct ChatContactRow: View {
    let contact: ChatContact
    var body: some View {
        HStack(spacing: 12) {
            AsyncImage(url: URL(string: contact.photoURL ?? "")) { phase in
                if let image = phase.image {
                    image.resizable().scaledToFill()
                } else {
                    Image(systemName: "person.circle.fill")
                        .resizable()
                        .foregroundColor(.primaryBlue)
                }
            }
            .frame(width: 50, height: 50)
            .clipShape(Circle())
            Text(contact.name)
                .font(.headline)
            Spacer()
        }
        .padding(.vertical, 8)
    }
}

// MARK: - Chat Message View (Redesigned)

struct ChatView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var authManager: AuthManager
    @EnvironmentObject var chatManager: ChatManager
    let conversation: Conversation
    
    @State private var messageText: String = ""
    
    private var otherParticipantName: String {
        let otherID = conversation.participantIDs.first { $0 != authManager.user?.id } ?? "unknown"
        return conversation.participantNames[otherID] ?? "Chat"
    }
    
    private var otherParticipantPhotoURL: String? {
        let otherID = conversation.participantIDs.first { $0 != authManager.user?.id } ?? "unknown"
        return conversation.participantPhotoURLs[otherID] ?? nil
    }
    
    var body: some View {
        VStack(spacing: 0) {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 4) { // Reduced spacing
                        if chatManager.messages.isEmpty {
                            Text("This is the beginning of your conversation with \(otherParticipantName).")
                                .foregroundColor(.textLight)
                                .padding()
                        } else {
                            ForEach(chatManager.messages) { message in
                                ChatBubble(message: message, otherUserPhotoURL: otherParticipantPhotoURL)
                                    .id(message.id)
                            }
                        }
                    }
                    .padding(.horizontal, 10)
                    .padding(.top, 10)
                }
                .background(Color(.systemGroupedBackground)) // Fixes "black screen"
                .onTapGesture {
                    UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                }
                .task {
                    guard let convoID = conversation.id else { return }
                    await chatManager.listenForMessages(conversationID: convoID)
                }
                .onChange(of: chatManager.messages) {
                    if let lastMessage = chatManager.messages.last {
                        withAnimation(.spring) {
                            proxy.scrollTo(lastMessage.id, anchor: .bottom)
                        }
                    }
                }
            }
            
            // --- *** NEW PROFESSIONAL INPUT BAR *** ---
            HStack(spacing: 12) {
                TextField("Message...", text: $messageText, axis: .vertical)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color(.systemGray5))
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                
                Button(action: sendMessage) {
                    Image(systemName: "arrow.up")
                        .font(.headline.weight(.bold))
                        .foregroundColor(.white)
                        .frame(width: 36, height: 36)
                        .background(messageText.isEmpty ? Color.secondaryGray : Color.primaryBlue)
                        .clipShape(Circle())
                }
                .disabled(messageText.isEmpty)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(Color(.systemBackground))
            .border(width: 1, edges: [.top], color: Color(.systemGray4))
            // --- *** END OF NEW INPUT BAR *** ---
        }
        .navigationTitle(otherParticipantName)
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbar {
            // --- *** NEW CUSTOM TOOLBAR (matches image_9acd99.png) *** ---
            ToolbarItem(placement: .navigationBarLeading) {
                HStack(spacing: 8) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "chevron.left")
                            .font(.headline.weight(.bold))
                    }
                    
                    AsyncImage(url: URL(string: otherParticipantPhotoURL ?? "")) { phase in
                        if let image = phase.image {
                            image.resizable().scaledToFill()
                        } else {
                            Image(systemName: "person.circle.fill")
                                .resizable()
                                .foregroundColor(.secondaryGray)
                        }
                    }
                    .frame(width: 30, height: 30)
                    .clipShape(Circle())
                    
                    VStack(alignment: .leading, spacing: 1) {
                        Text(otherParticipantName)
                            .font(.headline)
                        Text("Online") // Placeholder
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
        .toolbar(.hidden, for: .tabBar) // Hide the tab bar
    }
    
    private func sendMessage() {
        guard let convoID = conversation.id, let senderID = authManager.user?.id else { return }
        
        let textToSend = messageText
        messageText = ""
        
        Task {
            do {
                try await chatManager.sendMessage(
                    conversationID: convoID,
                    senderID: senderID,
                    text: textToSend
                )
            } catch {
                print("Failed to send message: \(error)")
                messageText = textToSend
            }
        }
    }
}

// --- *** NEW REDESIGNED CHAT BUBBLE *** ---
struct ChatBubble: View {
    @EnvironmentObject var authManager: AuthManager
    let message: ChatMessage
    let otherUserPhotoURL: String?
    
    private var isFromCurrentUser: Bool {
        message.senderID == authManager.user?.id
    }
    
    var body: some View {
        // This outer H-Stack pushes the bubble left or right
        HStack {
            if isFromCurrentUser {
                Spacer(minLength: 50)
            }
            
            // This V-Stack holds the bubble and the timestamp
            VStack(alignment: isFromCurrentUser ? .trailing : .leading, spacing: 3) {
                Text(message.text)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(isFromCurrentUser ? Color.primaryBlue : Color(.systemGray5))
                    .foregroundColor(isFromCurrentUser ? .white : .textDark)
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                
                if let timestamp = message.timestamp {
                    Text(timestamp.formatted(.dateTime.hour().minute()))
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 5)
                }
            }
            
            if !isFromCurrentUser {
                Spacer(minLength: 50)
            }
        }
    }
}

// --- Helpers (Unchanged) ---
extension View {
    func border(width: CGFloat, edges: [Edge], color: Color) -> some View {
        overlay(EdgeBorder(width: width, edges: edges).foregroundColor(color))
    }
}
struct EdgeBorder: Shape {
    var width: CGFloat
    var edges: [Edge]
    func path(in rect: CGRect) -> Path {
        var path = Path()
        for edge in edges {
            var x: CGFloat {
                switch edge {
                case .top, .bottom, .leading: return rect.minX
                case .trailing: return rect.maxX - width
                }
            }
            var y: CGFloat {
                switch edge {
                case .top, .leading, .trailing: return rect.minY
                case .bottom: return rect.maxY - width
                }
            }
            var w: CGFloat {
                switch edge {
                case .top, .bottom: return rect.width
                case .leading, .trailing: return self.width
                }
            }
            var h: CGFloat {
                switch edge {
                case .top, .bottom: return self.width
                case .leading, .trailing: return rect.height
                }
            }
            path.addPath(Path(CGRect(x: x, y: y, width: w, height: h)))
        }
        return path
    }
}
extension Date {
    func compactTimeAgo() -> String {
        if Calendar.current.isDateInToday(self) {
            return self.formatted(.dateTime.hour().minute())
        }
        if Calendar.current.isDateInYesterday(self) {
            return "Yesterday"
        }
        if let
            sevenDaysAgo = Calendar.current.date(byAdding: .day, value: -7, to: Date()),
            self >= sevenDaysAgo {
            return self.formatted(.dateTime.weekday())
        }
        return self.formatted(.dateTime.day().month())
    }
}
