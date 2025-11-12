// File: arafatrahman/myinstructor/MyInstructor-main/MyInstructor/Features/Settings/MessagingView.swift
// --- UPDATED: ChatView now calls the new markConversationAsRead function ---

import SwiftUI
import Combine

struct MessagingView: View {
    @EnvironmentObject var authManager: AuthManager
    @EnvironmentObject var chatManager: ChatManager
    
    @State private var searchText: String = ""
    @State private var conversationToPush: Conversation? = nil
    
    var filteredConversations: [Conversation] {
        if searchText.isEmpty {
            return chatManager.conversations
        } else {
            let lowercasedSearch = searchText.lowercased()
            return chatManager.conversations.filter { conversation in
                let otherID = conversation.participantIDs.first { $0 != authManager.user?.id } ?? "unknown"
                let otherName = conversation.participantNames[otherID] ?? ""
                let lastMessage = conversation.lastMessage ?? ""
                
                return otherName.lowercased().contains(lowercasedSearch) ||
                       lastMessage.lowercased().contains(lowercasedSearch)
            }
        }
    }
    
    var body: some View {
        
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
        
        VStack(spacing: 0) {
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(Color(.systemGray2))
                TextField("Search Messenger", text: $searchText)
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 12)
            .background(Color(.systemGray6))
            .padding(.horizontal, 10)
            .padding(.vertical, 10)
            .background(Color(.systemBackground))
            .border(width: 1, edges: [.bottom], color: Color(.systemGray5))
            
            List {
                if chatManager.conversations.isEmpty {
                    Text("You have no active conversations.")
                        .foregroundColor(.textLight)
                        .padding()
                } else if filteredConversations.isEmpty {
                    Text("No conversations match your search.")
                        .foregroundColor(.textLight)
                        .padding()
                } else {
                    ForEach(filteredConversations) { conversation in
                        Button(action: {
                            self.conversationToPush = conversation
                        }) {
                            ConversationRow(conversation: conversation)
                        }
                        .buttonStyle(.plain)
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            Button(role: .destructive) {
                                Task {
                                    await deleteConversation(conversation)
                                }
                            } label: {
                                Label("Delete", systemImage: "trash.fill")
                            }
                        }
                    }
                }
            }
            .listStyle(.plain)
        }
        .background(Color(.systemBackground))
        .navigationTitle("Start a Chat")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            guard let userID = authManager.user?.id else { return }
            await chatManager.listenForConversations(for: userID)
        }
        .onAppear {
            if conversationToPush != nil {
                conversationToPush = nil
            }
        }
        .onDisappear {
            chatManager.removeAllListeners()
        }
    }
    
    /// Hides the conversation from the user's list.
    private func deleteConversation(_ conversation: Conversation) async {
        guard let conversationID = conversation.id, let userID = authManager.user?.id else {
            print("Cannot delete: Missing conversation or user ID")
            return
        }
        
        do {
            try await chatManager.hideConversation(conversationID: conversationID, userID: userID)
            // The listener will automatically update the UI
        } catch {
            print("Error deleting conversation: \(error.localizedDescription)")
        }
    }
}


struct ConversationRow: View {
    @EnvironmentObject var authManager: AuthManager
    let conversation: Conversation
    
    private var otherParticipantName: String {
        let otherID = conversation.participantIDs.first { $0 != authManager.user?.id } ?? "unknown"
        return conversation.participantNames[otherID] ?? "Chat"
    }
    
    private var otherParticipantPhotoURL: String? {
        let otherID = conversation.participantIDs.first { $0 != authManager.user?.id } ?? "unknown"
        return conversation.participantPhotoURLs[otherID] ?? nil
    }
    
    private var initials: String {
        let names = otherParticipantName.split(separator: " ")
        if names.count >= 2 {
            return "\(names[0].first ?? " ")\(names[1].first ?? " ")"
        } else if let name = names.first {
            return "\(name.first ?? " ")"
        }
        return "JD"
    }
    
    private var lastMessagePreview: String {
        guard let lastMessage = conversation.lastMessage else { return "No messages yet." }
        return lastMessage
    }
    
    private var timestampString: String {
        guard let timestamp = conversation.lastMessageTimestamp else { return "" }
        
        if Calendar.current.isDateInToday(timestamp) {
            return timestamp.formatted(.dateTime.hour().minute())
        }
        if Calendar.current.isDateInYesterday(timestamp) {
            return "Yesterday"
        }
        return timestamp.compactTimeAgo()
    }
    
    private var isUnread: Bool {
        guard let currentUserID = authManager.user?.id else { return false }
        // It's unread if count > 0 AND the last message was NOT from us
        return conversation.unreadCount > 0 && conversation.lastMessageSenderID != currentUserID
    }

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(Color.primaryBlue)
                Text(initials.uppercased())
                    .font(.headline.bold())
                    .foregroundColor(.white)
            }
            .frame(width: 50, height: 50)

            VStack(alignment: .leading, spacing: 4) {
                Text(otherParticipantName)
                    .font(.headline)
                    .foregroundColor(.textDark)
                    .fontWeight(isUnread ? .bold : .regular) // Bold if unread
                
                Text(lastMessagePreview)
                    .font(.subheadline)
                    .foregroundColor(isUnread ? .primaryBlue : .textLight) // Blue if unread
                    .fontWeight(isUnread ? .bold : .regular) // Bold if unread
                    .lineLimit(1)
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 5) {
                Text(timestampString)
                    .font(.subheadline)
                    .foregroundColor(isUnread ? .primaryBlue : .textLight)
                    .fontWeight(isUnread ? .bold : .regular) // Bold if unread
                
                Circle()
                    .fill(Color.blue)
                    .frame(width: 10, height: 10)
                    .opacity(isUnread ? 1.0 : 0.0) // Show or hide dot
            }
            .frame(width: 70, alignment: .trailing) // Give stack a fixed width
        }
        .padding(.vertical, 8)
    }
}


struct ChatView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var authManager: AuthManager
    @EnvironmentObject var chatManager: ChatManager
    @EnvironmentObject var dataService: DataService
    
    let conversation: Conversation
    
    @State private var messageText: String = ""
    @State private var messageToEdit: ChatMessage? = nil
    
    @State private var otherUser: AppUser? = nil
    @State private var isLoadingOtherUser: Bool = true
    
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
            
            HStack(spacing: 8) {
                Button {
                    // chatManager.removeAllListeners() // This line was removed
                    dismiss()
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.headline.weight(.bold))
                        .foregroundColor(.white)
                }
                
                AsyncImage(url: URL(string: otherParticipantPhotoURL ?? "")) { phase in
                    if let image = phase.image {
                        image.resizable().scaledToFill()
                    } else {
                        Circle().fill(Color.white)
                    }
                }
                .frame(width: 30, height: 30)
                .background(Color.white)
                .clipShape(Circle())
                
                VStack(alignment: .leading, spacing: 1) {
                    Text(otherParticipantName)
                        .font(.headline)
                        .foregroundColor(.white)
                    Text(chatManager.isConnectionActive ? "Online" : "Connection Removed")
                        .font(.caption2)
                        .foregroundColor(.white.opacity(chatManager.isConnectionActive ? 0.8 : 1.0))
                        .fontWeight(chatManager.isConnectionActive ? .regular : .bold)
                }
                Spacer()
            }
            .padding(.horizontal)
            .padding(.bottom, 10)
            .padding(.top, 70)
            .background(Color.primaryBlue)
            
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 4) {
                        if chatManager.messages.isEmpty {
                            Text("This is the beginning of your conversation with \(otherParticipantName).")
                                .foregroundColor(.textLight)
                                .padding()
                        } else {
                            ForEach(chatManager.messages) { message in
                                ChatBubble(
                                    message: message,
                                    otherUserPhotoURL: otherParticipantPhotoURL,
                                    onEdit: { msg in
                                        self.messageToEdit = msg
                                        self.messageText = msg.text
                                    },
                                    onDelete: { msg in
                                        handleDelete(msg)
                                    }
                                )
                                .id(message.id)
                            }
                        }
                    }
                    .padding(.horizontal, 10)
                    .padding(.top, 10)
                }
                .background(Color(.systemBackground))
                .onTapGesture {
                    UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                }
                .task {
                    // --- *** THIS SECTION IS UPDATED *** ---
                    guard let convoID = conversation.id, let currentUserID = authManager.user?.id else { return }
                    
                    // Mark as read *before* fetching messages
                    // We pass the *entire conversation object* now for the check.
                    await chatManager.markConversationAsRead(conversation, currentUserID: currentUserID)
                    // --- *** END OF UPDATE *** ---
                    
                    isLoadingOtherUser = true
                    let otherUserID = conversation.participantIDs.first { $0 != currentUserID } ?? ""
                    self.otherUser = try? await dataService.fetchUser(withId: otherUserID)
                    isLoadingOtherUser = false
                    
                    chatManager.messages = []
                    await chatManager.listenForMessages(conversationID: convoID)
                    
                    if let currentUser = authManager.user, let otherUser = self.otherUser {
                        await chatManager.listenForConnectionStatus(currentUser: currentUser, otherUser: otherUser)
                    } else {
                        chatManager.isConnectionActive = false
                    }
                }
                .onChange(of: chatManager.messages) {
                    if let lastMessage = chatManager.messages.last {
                        withAnimation(.spring) {
                            proxy.scrollTo(lastMessage.id, anchor: .bottom)
                        }
                    }
                }
            }
            
            if !chatManager.isConnectionActive {
                Text("You no longer have permission to send messages in this chat.")
                    .font(.caption.bold())
                    .foregroundColor(.white)
                    .padding(8)
                    .frame(maxWidth: .infinity)
                    .background(Color.warningRed)
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
            }
            
            if let messageToEdit {
                HStack {
                    VStack(alignment: .leading) {
                        Text("Editing Message")
                            .font(.caption.bold())
                            .foregroundColor(.primaryBlue)
                        Text(messageToEdit.text)
                            .font(.caption)
                            .lineLimit(1)
                    }
                    Spacer()
                    Button {
                        self.messageToEdit = nil
                        self.messageText = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.horizontal)
                .padding(.vertical, 8)
                .background(Color.secondaryGray)
                .transition(.opacity.combined(with: .move(edge: .bottom)))
            }
            
            HStack(spacing: 12) {
                TextField("Type a message...", text: $messageText, axis: .vertical)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .stroke(Color(.systemGray4), lineWidth: 1)
                    )
                    .disabled(!chatManager.isConnectionActive || isLoadingOtherUser)
                
                Button(action: sendOrUpdateMessage) {
                    Image(systemName: "arrow.right")
                        .font(.headline.weight(.bold))
                        .foregroundColor(.white)
                        .frame(width: 36, height: 36)
                        .background(messageText.isEmpty || !chatManager.isConnectionActive ? Color.secondaryGray : Color.primaryBlue)
                        .clipShape(Circle())
                }
                .disabled(messageText.isEmpty || !chatManager.isConnectionActive || isLoadingOtherUser)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(Color(.systemBackground))
        }
        .animation(.default, value: messageToEdit)
        .animation(.default, value: chatManager.isConnectionActive)
        .navigationBarHidden(true)
        .ignoresSafeArea(edges: .top)
        .toolbar(.hidden, for: .tabBar)
    }
    
    private func sendOrUpdateMessage() {
        guard let convoID = conversation.id, let senderID = authManager.user?.id else { return }
        
        let textToSend = messageText
        messageText = ""
        
        if let messageToEdit = self.messageToEdit, let messageID = messageToEdit.id {
            self.messageToEdit = nil
            Task {
                do {
                    try await chatManager.updateMessage(conversationID: convoID, messageID: messageID, newText: textToSend)
                } catch {
                    print("Failed to update message: \(error)")
                    self.messageText = textToSend
                    self.messageToEdit = messageToEdit
                }
            }
        } else {
            Task {
                do {
                    try await chatManager.sendMessage(
                        conversationID: convoID,
                        senderID: senderID,
                        text: textToSend
                    )
                } catch let error as ChatError {
                    print("Chat blocked by manager: \(error.localizedDescription)")
                    messageText = textToSend
                } catch {
                    print("Failed to send message: \(error)")
                    messageText = textToSend
                }
            }
        }
    }
    
    private func handleDelete(_ message: ChatMessage) {
        guard let convoID = conversation.id, let messageID = message.id else { return }
        Task {
            do {
                try await chatManager.deleteMessage(conversationID: convoID, messageID: messageID)
            } catch {
                print("Failed to delete message: \(error)")
            }
        }
    }
}


struct ChatBubble: View {
    @EnvironmentObject var authManager: AuthManager
    let message: ChatMessage
    let otherUserPhotoURL: String?
    
    let onEdit: (ChatMessage) -> Void
    let onDelete: (ChatMessage) -> Void
    
    private var isFromCurrentUser: Bool {
        message.senderID == authManager.user?.id
    }
    
    var body: some View {
        HStack {
            if isFromCurrentUser {
                Spacer(minLength: 50)
            }
            
            VStack(alignment: isFromCurrentUser ? .trailing : .leading, spacing: 3) {
                Text(message.isDeleted == true ? "This message was deleted." : message.text)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(isFromCurrentUser ? Color.primaryBlue : Color(.systemGray5))
                    .foregroundColor(isFromCurrentUser ? .white : (message.isDeleted == true ? .textLight : .textDark))
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .italic(message.isDeleted == true)
                
                if let timestamp = message.timestamp, message.isDeleted != true {
                    HStack(spacing: 4) {
                        if message.isEdited == true {
                            Text("(edited)")
                        }
                        Text(timestamp.formatted(.dateTime.hour().minute()))
                    }
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 5)
                }
            }
            .contextMenu {
                if isFromCurrentUser && message.isDeleted != true {
                    Button {
                        onEdit(message)
                    } label: {
                        Label("Edit", systemImage: "pencil")
                    }
                    
                    Button(role: .destructive) {
                        onDelete(message)
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                }
            }
            
            if !isFromCurrentUser {
                Spacer(minLength: 50)
            }
        }
    }
}


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
            return self.formatted(Date.FormatStyle().weekday(.abbreviated))
        }
        return self.formatted(.dateTime.day().month().year(.twoDigits))
    }
}
