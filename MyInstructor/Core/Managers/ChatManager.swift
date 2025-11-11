// File: MyInstructor/Core/Managers/ChatManager.swift
// --- UPDATED: To add a live connection status listener ---

import Foundation
import Combine
import FirebaseFirestore

class ChatManager: ObservableObject {
    private let db = Firestore.firestore()
    private var conversationsCollection: CollectionReference {
        db.collection("conversations")
    }
    
    private var requestsCollection: CollectionReference {
        db.collection("student_requests")
    }
    
    @Published var conversations = [Conversation]()
    @Published var messages = [ChatMessage]()
    
    // --- *** NEW *** ---
    // This will be true or false, and the UI will watch it
    @Published var isConnectionActive: Bool = true
    
    private var conversationsListener: ListenerRegistration?
    private var messagesListener: ListenerRegistration?
    
    // --- *** NEW *** ---
    // A new listener to watch the student_requests status
    private var statusListener: ListenerRegistration?
    
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

    // --- *** NEW FUNCTION *** ---
    /// Starts a live listener on the `student_requests` collection.
    /// This sets `isConnectionActive` to false if a `.blocked` or `.denied` status is found.
    @MainActor
    func listenForConnectionStatus(currentUser: AppUser, otherUser: AppUser) {
        guard let currentUserID = currentUser.id, let otherUserID = otherUser.id else {
            self.isConnectionActive = false
            return
        }
        
        statusListener?.remove() // Remove old one
        
        // Determine who is student and instructor
        let (studentID, instructorID) = (currentUser.role == .student) ?
            (currentUserID, otherUserID) : (otherUserID, currentUserID)
            
        let deniedOrBlockedStatuses = [RequestStatus.blocked.rawValue, RequestStatus.denied.rawValue]
        
        // Query for a request that is .blocked OR .denied
        let query = requestsCollection
            .whereField("studentID", isEqualTo: studentID)
            .whereField("instructorID", isEqualTo: instructorID)
            .whereField("status", in: deniedOrBlockedStatuses)
            .limit(to: 1)
        
        self.statusListener = query.addSnapshotListener { snapshot, error in
            if let error {
                print("Error listening for connection status: \(error.localizedDescription)")
                // Default to active if there's an error
                self.isConnectionActive = true
                return
            }
            
            // If we find any document, it means the connection is blocked or denied.
            if let documents = snapshot?.documents, !documents.isEmpty {
                print("!!! ChatManager Status: Connection is DENIED or BLOCKED.")
                self.isConnectionActive = false
            } else {
                // No denied or blocked requests found.
                print("ChatManager Status: Connection is Active.")
                self.isConnectionActive = true
            }
        }
    }
    
    func sendMessage(conversationID: String, senderID: String, text: String) async throws {
        // --- *** NEW FAILSAFE *** ---
        // Final check. If this is false, stop the message from being sent.
        guard isConnectionActive else {
            print("!!! ChatManager: sendMessage blocked. Connection is not active.")
            throw ChatError.blocked
        }
        
        let message = ChatMessage(senderID: senderID, text: text)
        
        try await conversationsCollection.document(conversationID)
            .collection("messages")
            .addDocument(from: message)
            
        try await conversationsCollection.document(conversationID).updateData([
            "lastMessage": text,
            "lastMessageTimestamp": FieldValue.serverTimestamp()
        ])
    }
    
    func deleteMessage(conversationID: String, messageID: String) async throws {
        let messageRef = conversationsCollection.document(conversationID)
            .collection("messages")
            .document(messageID)
            
        try await messageRef.updateData([
            "text": "This message was deleted.",
            "isDeleted": true
        ])
    }
    
    func updateMessage(conversationID: String, messageID: String, newText: String) async throws {
        let messageRef = conversationsCollection.document(conversationID)
            .collection("messages")
            .document(messageID)
            
        try await messageRef.updateData([
            "text": newText,
            "isEdited": true
        ])
    }

    func getOrCreateConversation(currentUser: AppUser, otherUser: AppUser) async throws -> Conversation {
        guard let currentUserID = currentUser.id, let otherUserID = otherUser.id else {
            throw NSError(domain: "ChatManager", code: 0, userInfo: [NSLocalizedDescriptionKey: "Invalid user IDs"])
        }
        
        // 1. Determine who is the student and who is the instructor
        let (studentID, instructorID) = (currentUser.role == .student) ?
            (currentUserID, otherUserID) : (otherUserID, currentUserID)

        // 2. Check if a 'blocked' or 'denied' request exists
        let deniedOrBlockedStatuses = [RequestStatus.blocked.rawValue, RequestStatus.denied.rawValue]

        let blockQuery = try await requestsCollection
            .whereField("studentID", isEqualTo: studentID)
            .whereField("instructorID", isEqualTo: instructorID)
            .whereField("status", in: deniedOrBlockedStatuses) // <-- This is the fix from before
            .limit(to: 1)
            .getDocuments()

        // 3. If a block or denied request exists, throw an error
        if !blockQuery.isEmpty {
            print("!!! ChatManager: Blocked or Denied. Chat cannot be initiated.")
            throw ChatError.blocked // This relies on ChatModels.swift
        }
        
        // 4. Check if a conversation already exists
        let query = conversationsCollection
            .whereField("participantIDs", arrayContains: currentUserID)
        
        let snapshot = try await query.getDocuments()
        
        for doc in snapshot.documents {
            let participantIDs = doc.data()["participantIDs"] as? [String] ?? []
            if participantIDs.contains(otherUserID) {
                print("ChatManager: Found existing conversation.")
                return try doc.data(as: Conversation.self)
            }
        }
        
        // 5. No conversation exists. Create a new one.
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

    
    // MARK: - Cleanup
    
    func removeAllListeners() {
        conversationsListener?.remove()
        messagesListener?.remove()
        // --- *** NEW *** ---
        statusListener?.remove()
        
        conversationsListener = nil
        messagesListener = nil
        // --- *** NEW *** ---
        statusListener = nil
        
        self.conversations = []
        self.messages = []
        
        // --- *** NEW *** ---
        // Reset to default
        self.isConnectionActive = true
    }
}
