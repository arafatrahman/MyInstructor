// File: arafatrahman/myinstructor/MyInstructor-main/MyInstructor/Features/Settings/MessagingView.swift
// --- FULL REDESIGN: Fixes compiler errors and implements new UI ---
// --- UPDATED: Embedded chat loading logic to remove ChatLoadingView from the navigation stack ---

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
    @EnvironmentObject var chatManager: ChatManager // <-- ADDED
    
    @State private var contacts: [ChatContact] = []
    @State private var isLoading = true
    
    // --- ADDED for direct navigation ---
    @State private var conversationToPush: Conversation? = nil
    @State private var isOpeningChat = false
    @State private var selectedContact: ChatContact? = nil
    
    var body: some View {
        
        // This NavigationLink is hidden, but it activates
        // as soon as 'conversationToPush' is set.
        if let conversation = conversationToPush {
            NavigationLink(
                destination: ChatView(conversation: conversation),
                isActive: .init(
                    get: { conversationToPush != nil },
                    set: { isActive in
                        if !isActive { conversationToPush = nil }
                    }
                ),
                label: { EmptyView() }
            )
            .hidden()
        }
        
        List {
            if isLoading {
                ProgressView()
            } else if contacts.isEmpty {
                Text(authManager.user?.role == .instructor ? "No approved students yet." : "No approved instructors yet.")
                    .foregroundColor(.textLight)
                    .padding()
            } else {
                // --- REPLACED NavigationLink with Button ---
                ForEach(contacts) { contact in
                    Button(action: {
                        self.selectedContact = contact
                        self.isOpeningChat = true
                        Task {
                            await openChat(with: contact)
                        }
                    }) {
                        HStack {
                            ChatContactRow(contact: contact)
                            Spacer()
                            if isOpeningChat && selectedContact == contact {
                                ProgressView()
                                    .frame(width: 20)
                            } else {
                                Image(systemName: "chevron.right")
                                    .font(.caption.weight(.bold))
                                    .foregroundColor(Color(.systemGray3))
                            }
                        }
                    }
                    .buttonStyle(.plain)
                    .disabled(isOpeningChat)
                }
            }
        }
        .listStyle(.plain)
        .navigationTitle("Start a Chat")
        .task {
            await fetchContacts()
        }
        // This resets the navigation state when the view appears,
        // so you don't get stuck in a navigation loop.
        .onAppear {
            if conversationToPush != nil {
                conversationToPush = nil
            }
            if isOpeningChat {
                isOpeningChat = false
                selectedContact = nil
            }
        }
    }
    
    // --- ADDED FUNCTION ---
    func openChat(with contact: ChatContact) async {
        guard let currentUser = authManager.user else {
            isOpeningChat = false
            selectedContact = nil
            return
        }
        
        do {
            let conversation = try await chatManager.getOrCreateConversation(
                currentUser: currentUser,
                otherUser: contact.appUser
            )
            self.conversationToPush = conversation // This triggers the NavigationLink
        } catch {
            print("Error getting or creating conversation: \(error)")
            // TODO: Show an error alert
            isOpeningChat = false
            selectedContact = nil
        }
        
        // Note: isOpeningChat is reset in onAppear
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
            
            // --- *** CUSTOM HEADER (from screenshot) *** ---
            HStack(spacing: 8) {
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.headline.weight(.bold))
                        .foregroundColor(.white)
                }
                
                // Screenshot shows a white circle placeholder
                AsyncImage(url: URL(string: otherParticipantPhotoURL ?? "")) { phase in
                    if let image = phase.image {
                        image.resizable().scaledToFill()
                    } else {
                        // White circle placeholder
                        Circle().fill(Color.white)
                    }
                }
                .frame(width: 30, height: 30)
                .background(Color.white) // Ensure background is white
                .clipShape(Circle())
                
                VStack(alignment: .leading, spacing: 1) {
                    Text(otherParticipantName)
                        .font(.headline)
                        .foregroundColor(.white)
                    Text("Online") // Placeholder
                        .font(.caption2)
                        .foregroundColor(.white.opacity(0.8))
                }
                Spacer()
            }
            .padding(.horizontal)
            .padding(.bottom, 10)
            .padding(.top, 50) // Manual safe area padding
            .background(Color.primaryBlue)
            // --- *** END OF CUSTOM HEADER *** ---
            
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
                .background(Color(.systemBackground)) // --- *** CHANGED (to white) *** ---
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
            
            // --- *** PROFESSIONAL INPUT BAR (from screenshot) *** ---
            HStack(spacing: 12) {
                TextField("Type a message...", text: $messageText, axis: .vertical) // --- *** CHANGED PLACEHOLDER *** ---
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(
                        // --- *** CHANGED (from fill to border) *** ---
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .stroke(Color(.systemGray4), lineWidth: 1)
                    )
                
                Button(action: sendMessage) {
                    Image(systemName: "arrow.right") // --- *** CHANGED ICON *** ---
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
            // --- *** END OF NEW INPUT BAR *** ---
        }
        .navigationBarHidden(true) // Hide the default navigation bar
        .ignoresSafeArea(edges: .top) // Allow blue header to fill safe area
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

// --- *** CHAT BUBBLE (No changes were needed) *** ---
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
