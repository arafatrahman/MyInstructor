// File: arafatrahman/myinstructor/MyInstructor-main/MyInstructor/Features/Settings/MessagingView.swift
// --- UPDATED: Added a background color to the VStack to fix the transparent navigation bar ---

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
        
        VStack(spacing: 0) {
            // --- *** SEARCH BAR (from screenshot) *** ---
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
            .background(Color(.systemBackground)) // Match list background
            .border(width: 1, edges: [.bottom], color: Color(.systemGray5))
            
            // --- *** UPDATED LIST (to show conversations) *** ---
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
                    }
                }
            }
            .listStyle(.plain)
        }
        // --- *** THIS IS THE FIX *** ---
        // Set the background for the entire view to white.
        .background(Color(.systemBackground))
        // --- *** END OF FIX *** ---
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
}

// --- *** CONVERSATION ROW (Unchanged) *** ---
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
        return "JD" // Default
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
                Text(lastMessagePreview)
                    .font(.subheadline)
                    .foregroundColor(.textLight)
                    .lineLimit(1)
            }
            
            Spacer()
            
            Text(timestampString)
                .font(.subheadline)
                .foregroundColor(.textLight)
        }
        .padding(.vertical, 8)
    }
}


// MARK: - Chat Message View (Unchanged)

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
            
            // --- *** CUSTOM HEADER (This is correct for this screen) *** ---
            HStack(spacing: 8) {
                Button {
                    chatManager.removeAllListeners()
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
                    Text("Online")
                        .font(.caption2)
                        .foregroundColor(.white.opacity(0.8))
                }
                Spacer()
            }
            .padding(.horizontal)
            .padding(.bottom, 10)
            .padding(.top, 50)
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
                                ChatBubble(message: message, otherUserPhotoURL: otherParticipantPhotoURL)
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
                    guard let convoID = conversation.id else { return }
                    chatManager.messages = []
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
            
            // --- *** INPUT BAR (This is correct for this screen) *** ---
            HStack(spacing: 12) {
                TextField("Type a message...", text: $messageText, axis: .vertical)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .stroke(Color(.systemGray4), lineWidth: 1)
                    )
                
                Button(action: sendMessage) {
                    Image(systemName: "arrow.right")
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
        }
        .navigationBarHidden(true)
        .ignoresSafeArea(edges: .top)
        .toolbar(.hidden, for: .tabBar)
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

// --- *** CHAT BUBBLE (Unchanged) *** ---
struct ChatBubble: View {
    @EnvironmentObject var authManager: AuthManager
    let message: ChatMessage
    let otherUserPhotoURL: String?
    
    private var isFromCurrentUser: Bool {
        message.senderID == authManager.user?.id
    }
    
    var body: some View {
        HStack {
            if isFromCurrentUser {
                Spacer(minLength: 50)
            }
            
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
            return self.formatted(Date.FormatStyle().weekday(.abbreviated))
        }
        return self.formatted(.dateTime.day().month().year(.twoDigits))
    }
}
