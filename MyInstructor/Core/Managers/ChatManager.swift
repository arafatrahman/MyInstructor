// File: MyInstructor/Core/Managers/ChatManager.swift
// (This is a NEW file)

import Foundation
import Combine
import FirebaseFirestore

class ChatManager: ObservableObject {
    private let db = Firestore.firestore()
    private var conversationsCollection: CollectionReference {
        db.collection("conversations")
    }
    
    @Published var conversations = [Conversation]()
    @Published var messages = [ChatMessage]()
    
    private var conversationsListener: ListenerRegistration?
    private var messagesListener: ListenerRegistration?
    
    // MARK: - Conversation List
    
    /// Sets up a real-time listener for all conversations for a user
    @MainActor
    func listenForConversations(for userID: String) {
        conversationsListener?.remove() // Remove old listener
        
        let query = conversationsCollection
            .whereField("participantIDs", arrayContains: userID)
            .order(by: "lastMessageTimestamp", descending: true)
            
        self.conversationsListener = query.addSnapshotListener { snapshot, error in
            if let error {
                print("Error fetching conversations: \(error.localizedDescription)")
                return
            }
            
            guard let documents = snapshot?.documents else { return }
            
            self.conversations = documents.compactMap {
                try? $0.data(as: Conversation.self)
            }
            print("ChatManager: Fetched \(self.conversations.count) conversations")
        }
    }
    
    // MARK: - Chat Message View
    
    /// Sets up a real-time listener for messages within one conversation
    @MainActor
    func listenForMessages(conversationID: String) {
        messagesListener?.remove() // Remove old listener
        
        let query = conversationsCollection.document(conversationID)
            .collection("messages")
            .order(by: "timestamp", descending: false) // Show oldest first
            
        self.messagesListener = query.addSnapshotListener { snapshot, error in
            if let error {
                print("Error fetching messages: \(error.localizedDescription)")
                return
            }
            
            guard let documents = snapshot?.documents else { return }
            
            self.messages = documents.compactMap {
                try? $0.data(as: ChatMessage.self)
            }
            print("ChatManager: Fetched \(self.messages.count) messages")
        }
    }
    
    /// Sends a new message and updates the conversation's last message
    func sendMessage(conversationID: String, senderID: String, text: String) async throws {
        // 1. Create the new message
        let message = ChatMessage(senderID: senderID, text: text)
        
        // 2. Add message to sub-collection
        try await conversationsCollection.document(conversationID)
            .collection("messages")
            .addDocument(from: message)
            
        // 3. Update the conversation's 'lastMessage' preview
        try await conversationsCollection.document(conversationID).updateData([
            "lastMessage": text,
            "lastMessageTimestamp": FieldValue.serverTimestamp()
        ])
    }
    
    // MARK: - Cleanup
    
    /// Call this to remove listeners when logging out
    func removeAllListeners() {
        conversationsListener?.remove()
        messagesListener?.remove()
        conversationsListener = nil
        messagesListener = nil
        self.conversations = []
        self.messages = []
    }
}
