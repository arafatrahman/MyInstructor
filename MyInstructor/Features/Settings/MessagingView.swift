// File: arafatrahman/myinstructor/MyInstructor-main/MyInstructor/Features/Settings/MessagingView.swift
// --- UPDATED: Removed the redeclared AppUser, UserRole, etc. ---

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
        NavigationView {
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
                    // Convert Student to a minimal AppUser for the chat loader
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

// MARK: - Chat Message View (Unchanged from before)

struct ChatView: View {
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
                    LazyVStack(spacing: 12) {
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
                    .padding(.horizontal)
                    .padding(.top, 10)
                }
                .background(Color(.systemGroupedBackground))
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
            
            HStack(spacing: 12) {
                TextField("Message...", text: $messageText, axis: .vertical)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color(.systemGray5))
                    .clipShape(Capsule())
                
                Button(action: sendMessage) {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 32))
                        .foregroundColor(messageText.isEmpty ? .secondaryGray : .primaryBlue)
                }
                .disabled(messageText.isEmpty)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(Color(.systemBackground))
            .border(width: 1, edges: [.top], color: Color(.systemGray4))
        }
        .navigationTitle(otherParticipantName)
        .navigationBarTitleDisplayMode(.inline)
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

struct ChatBubble: View {
    @EnvironmentObject var authManager: AuthManager
    let message: ChatMessage
    let otherUserPhotoURL: String?
    
    private var isFromCurrentUser: Bool {
        message.senderID == authManager.user?.id
    }
    
    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            
            if isFromCurrentUser {
                Spacer()
            } else {
                AsyncImage(url: URL(string: otherUserPhotoURL ?? "")) { phase in
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
            }
            
            Text(message.text)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(isFromCurrentUser ? Color.primaryBlue : Color(.systemGray5))
                .foregroundColor(isFromCurrentUser ? .white : .textDark)
                .clipShape(RoundedRectangle(cornerRadius: 15, style: .continuous))
            
            if !isFromCurrentUser {
                Spacer()
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

// --- *** ALL HELPER MODELS HAVE BEEN REMOVED TO FIX THE ERRORS *** ---
