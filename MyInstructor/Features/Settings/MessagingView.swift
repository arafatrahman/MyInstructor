// File: arafatrahman/myinstructor/MyInstructor-main/MyInstructor/Features/Settings/MessagingView.swift
// --- FULL REBUILD of the chat system ---

import SwiftUI
import Combine

// Flow Item 24: Messaging / Chat
struct MessagingView: View {
    @EnvironmentObject var authManager: AuthManager
    @EnvironmentObject var chatManager: ChatManager
    
    var body: some View {
        NavigationView {
            // The list now reads from the ChatManager's published array
            List {
                if chatManager.conversations.isEmpty {
                    Text("No messages yet. Once an instructor approves you, your chat will appear here.")
                        .foregroundColor(.textLight)
                        .padding()
                } else {
                    ForEach(chatManager.conversations) { convo in
                        NavigationLink {
                            // Pass the real conversation object
                            ChatView(conversation: convo)
                        } label: {
                            ConversationRow(conversation: convo)
                        }
                        .listRowSeparator(.hidden)
                    }
                }
            }
            .listStyle(.plain)
            .navigationTitle("Messages")
            .task {
                // Tell the manager to start listening for conversations
                guard let userID = authManager.user?.id else { return }
                await chatManager.listenForConversations(for: userID)
            }
            .onDisappear {
                // You might want to remove the listener here,
                // or in AuthManager on logout
            }
        }
    }
}

// This view row now intelligently finds the "other person"
struct ConversationRow: View {
    @EnvironmentObject var authManager: AuthManager
    let conversation: Conversation
    
    // Get the ID, Name, and Photo of the *other* user in the chat
    private var otherParticipantID: String {
        conversation.participantIDs.first { $0 != authManager.user?.id } ?? "unknown"
    }
    private var otherParticipantName: String {
        conversation.participantNames[otherParticipantID] ?? "Chat"
    }
    private var otherParticipantPhotoURL: String? {
        conversation.participantPhotoURLs[otherParticipantID] ?? nil
    }
    
    var body: some View {
        HStack {
            AsyncImage(url: URL(string: otherParticipantPhotoURL ?? "")) { phase in
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
                Text(otherParticipantName)
                    .font(.headline)
                Text(conversation.lastMessage ?? "No messages yet")
                    .font(.subheadline)
                    .foregroundColor(conversation.unreadCount > 0 ? .textDark : .textLight)
                    .lineLimit(1)
            }
            Spacer()
            
            if conversation.unreadCount > 0 {
                Text("\(conversation.unreadCount)")
                    .font(.caption).bold()
                    .padding(8)
                    .background(Color.warningRed)
                    .foregroundColor(.white)
                    .clipShape(Circle())
            }
        }
        .padding(.vertical, 5)
    }
}

// Individual Chat View
struct ChatView: View {
    @EnvironmentObject var authManager: AuthManager
    @EnvironmentObject var chatManager: ChatManager
    let conversation: Conversation
    
    @State private var messageText: String = ""
    
    private var otherParticipantName: String {
        let otherID = conversation.participantIDs.first { $0 != authManager.user?.id } ?? "unknown"
        return conversation.participantNames[otherID] ?? "Chat"
    }
    
    var body: some View {
        VStack(spacing: 0) {
            ScrollViewReader { proxy in
                List {
                    // The list now reads from the manager's published messages
                    if chatManager.messages.isEmpty {
                        Text("This is the beginning of your conversation with \(otherParticipantName).")
                            .foregroundColor(.textLight)
                            .listRowSeparator(.hidden)
                    } else {
                        ForEach(chatManager.messages) { message in
                            ChatBubble(message: message)
                                .id(message.id)
                                .listRowSeparator(.hidden)
                                .listRowBackground(Color.clear)
                        }
                    }
                }
                .listStyle(.plain)
                .task {
                    // Start listening for messages in this specific chat
                    guard let convoID = conversation.id else { return }
                    await chatManager.listenForMessages(conversationID: convoID)
                }
                .onChange(of: chatManager.messages) {
                    // When a new message appears, scroll to bottom
                    if let lastMessage = chatManager.messages.last {
                        withAnimation {
                            proxy.scrollTo(lastMessage.id, anchor: .bottom)
                        }
                    }
                }
            }
            
            // Input Box
            HStack(alignment: .bottom) {
                // Attach Menu (Quick actions: Book, Pay Now, Share Progress)
                Menu {
                    Button("Book Lesson") { print("Book Lesson pressed") }
                    Button("Pay Now") { print("Pay Now pressed") }
                    Button("Share Lesson Summary") { print("Share Summary pressed") }
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.title)
                        .foregroundColor(.primaryBlue)
                }
                
                TextField("Message...", text: $messageText, axis: .vertical)
                    .padding(10)
                    .background(Color.secondaryGray)
                    .clipShape(RoundedRectangle(cornerRadius: 15))
                
                Button(action: sendMessage) {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.largeTitle)
                        .foregroundColor(.primaryBlue)
                }
                .disabled(messageText.isEmpty)
            }
            .padding([.horizontal, .bottom])
            .background(Color(.systemBackground))
        }
        .navigationTitle(otherParticipantName)
        .navigationBarTitleDisplayMode(.inline)
    }
    
    private func sendMessage() {
        guard let convoID = conversation.id, let senderID = authManager.user?.id else { return }
        
        let textToSend = messageText
        messageText = "" // Clear text field immediately
        
        Task {
            do {
                try await chatManager.sendMessage(
                    conversationID: convoID,
                    senderID: senderID,
                    text: textToSend
                )
            } catch {
                print("Failed to send message: \(error)")
                messageText = textToSend // Put text back if send failed
            }
        }
    }
}

// This view now compares the message's senderID to the logged-in user's ID
struct ChatBubble: View {
    @EnvironmentObject var authManager: AuthManager
    let message: ChatMessage
    
    private var isFromCurrentUser: Bool {
        message.senderID == authManager.user?.id
    }
    
    var body: some View {
        HStack {
            if isFromCurrentUser { Spacer() }
            
            Text(message.text)
                .padding(12)
                .background(isFromCurrentUser ? Color.primaryBlue : Color(.systemGray4))
                .foregroundColor(isFromCurrentUser ? .white : .textDark)
                .clipShape(RoundedRectangle(cornerRadius: 15, style: .continuous))
                .shadow(color: .black.opacity(0.05), radius: 2)
            
            if !isFromCurrentUser { Spacer() }
        }
        .padding(.horizontal, 4)
    }
}
