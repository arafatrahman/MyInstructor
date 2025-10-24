import SwiftUI
import Combine

// Flow Item 24: Messaging / Chat
struct MessagingView: View {
    
    // Mock list of recent conversations
    @State private var conversations: [Conversation] = [
        Conversation(name: "Mr. Smith", lastMessage: "See you at 3PM tomorrow.", unreadCount: 1, isInstructor: true),
        Conversation(name: "Emma Watson", lastMessage: "Yes, I confirmed the payment.", unreadCount: 0, isInstructor: false),
        Conversation(name: "Alex Johnson", lastMessage: "Having trouble with roundabouts.", unreadCount: 2, isInstructor: false)
    ]
    
    var body: some View {
        NavigationView {
            List {
                // List: Recent conversations
                ForEach(conversations) { convo in
                    NavigationLink {
                        ChatView(conversation: convo)
                    } label: {
                        ConversationRow(conversation: convo)
                    }
                    .listRowSeparator(.hidden)
                }
            }
            .listStyle(.plain)
            .navigationTitle("Messages")
        }
    }
}

struct Conversation: Identifiable {
    let id = UUID()
    let name: String
    let lastMessage: String
    var unreadCount: Int
    let isInstructor: Bool
}

struct ConversationRow: View {
    let conversation: Conversation
    
    var body: some View {
        HStack {
            Image(systemName: conversation.isInstructor ? "person.fill.viewfinder" : "person.crop.circle.fill")
                .resizable()
                .frame(width: 45, height: 45)
                .foregroundColor(conversation.isInstructor ? .primaryBlue : .accentGreen)
            
            VStack(alignment: .leading) {
                Text(conversation.name)
                    .font(.headline)
                Text(conversation.lastMessage)
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
    let conversation: Conversation
    
    @State private var messageText: String = ""
    
    // Mock chat bubbles
    @State private var messages: [ChatMessage] = [
        ChatMessage(text: "Are we still meeting at the library?", isFromUser: true),
        ChatMessage(text: "Yes! And don't forget your learner's permit.", isFromUser: false),
    ]
    
    var body: some View {
        VStack(spacing: 0) {
            ScrollViewReader { proxy in
                List {
                    ForEach(messages) { message in
                        ChatBubble(message: message)
                            .id(message.id)
                            .listRowSeparator(.hidden)
                            .listRowBackground(Color.clear)
                    }
                }
                .listStyle(.plain)
                .onAppear {
                    if let last = messages.last {
                        proxy.scrollTo(last.id, anchor: .bottom)
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
                    .overlay(
                        RoundedRectangle(cornerRadius: 15).stroke(Color.primaryBlue.opacity(0.3), lineWidth: 1)
                    )
                
                Button {
                    // Send message action
                    messages.append(ChatMessage(text: messageText, isFromUser: true))
                    messageText = ""
                } label: {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.largeTitle)
                        .foregroundColor(.primaryBlue)
                }
                .disabled(messageText.isEmpty)
            }
            .padding([.horizontal, .bottom])
        }
        .navigationTitle(conversation.name)
    }
}

// Global scope structs for the ChatView to reference
struct ChatMessage: Identifiable {
    let id = UUID()
    let text: String
    let isFromUser: Bool // Blue = you, Grey = them
}

struct ChatBubble: View {
    let message: ChatMessage
    
    var body: some View {
        HStack {
            if message.isFromUser { Spacer() }
            
            Text(message.text)
                .padding(12)
                .background(message.isFromUser ? Color.primaryBlue : Color(.systemGray4))
                .foregroundColor(message.isFromUser ? .white : .textDark)
                .clipShape(RoundedRectangle(cornerRadius: 15, style: .continuous))
                .shadow(color: .black.opacity(0.05), radius: 2)
            
            if !message.isFromUser { Spacer() }
        }
    }
}
