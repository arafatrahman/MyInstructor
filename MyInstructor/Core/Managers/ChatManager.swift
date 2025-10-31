// File: MyInstructor/Core/Managers/ChatManager.swift
// --- UPDATED: Added getOrCreateConversation ---

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
            self.conversations = documents.compactMap { try? $0.data(as: Conversation.self) }
            print("ChatManager: Fetched \(self.conversations.count) conversations")
        }
    }
    
    // MARK: - Chat Message View
    
    @MainActor
    func listenForMessages(conversationID: String) {
        messagesListener?.remove() // Remove old listener
        
        let query = conversationsCollection.document(conversationID)
            .collection("messages")
            .order(by: "timestamp", descending: false)
            
        self.messagesListener = query.addSnapshotListener { snapshot, error in
            if let error {
                print("Error fetching messages: \(error.localizedDescription)")
                return
            }
            guard let documents = snapshot?.documents else { return }
            self.messages = documents.compactMap { try? $0.data(as: ChatMessage.self) }
            print("ChatManager: Fetched \(self.messages.count) messages")
        }
    }
    
    func sendMessage(conversationID: String, senderID: String, text: String) async throws {
        let message = ChatMessage(senderID: senderID, text: text)
        
        try await conversationsCollection.document(conversationID)
            .collection("messages")
            .addDocument(from: message)
            
        try await conversationsCollection.document(conversationID).updateData([
            "lastMessage": text,
            "lastMessageTimestamp": FieldValue.serverTimestamp()
        ])
    }

    // --- *** NEW FUNCTION *** ---
    // This is the new function to start a chat
    func getOrCreateConversation(currentUser: AppUser, otherUser: AppUser) async throws -> Conversation {
        guard let currentUserID = currentUser.id, let otherUserID = otherUser.id else {
            throw NSError(domain: "ChatManager", code: 0, userInfo: [NSLocalizedDescriptionKey: "Invalid user IDs"])
        }
        
        // 1. Check if a conversation already exists
        let query = conversationsCollection
            .whereField("participantIDs", arrayContains: currentUserID)
        
        let snapshot = try await query.getDocuments()
        
        for doc in snapshot.documents {
            let participantIDs = doc.data()["participantIDs"] as? [String] ?? []
            if participantIDs.contains(otherUserID) {
                // A conversation already exists, return it
                print("ChatManager: Found existing conversation.")
                return try doc.data(as: Conversation.self)
            }
        }
        
        // 2. No conversation exists. Create a new one.
        print("ChatManager: Creating new conversation...")
        let newConversation = Conversation(
            participantIDs: [currentUserID, otherUserID],
            participantNames: [
                currentUserID: currentUser.name ?? "Me",
                otherUserID: otherUser.name ?? "User"
            ],
            participantPhotoURLs: [
                currentUserID: currentUser.photoURL,
                otherUserID: otherUser.photoURL
            ],
            lastMessage: "You are now connected!",
            lastMessageTimestamp: Date()
        )
        
        let newDocRef = try conversationsCollection.addDocument(from: newConversation)
        let newDoc = try await newDocRef.getDocument()
        return try newDoc.data(as: Conversation.self)
    }
    // --- *** END NEW FUNCTION *** ---

    
    // MARK: - Cleanup
    
    func removeAllListeners() {
        conversationsListener?.remove()
        messagesListener?.remove()
        conversationsListener = nil
        messagesListener = nil
        self.conversations = []
        self.messages = []
    }
}
