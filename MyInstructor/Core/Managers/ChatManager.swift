// File: MyInstructor/Core/Managers/ChatManager.swift
// --- UPDATED: Fixed permissions error by removing unnecessary 'getDocument' call ---

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
    @Published var isConnectionActive: Bool = true
    
    private var conversationsListener: ListenerRegistration?
    private var messagesListener: ListenerRegistration?
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
            
            // Filter out any that are "hidden" for the current user
            let allConversations = documents.compactMap { try? $0.data(as: Conversation.self) }
            self.conversations = allConversations.filter { conversation in
                !(conversation.hiddenFor?.contains(userID) ?? false)
            }
            
            print("ChatManager: Fetched \(self.conversations.count) visible conversations")
        }
    }
    
    // --- (New function to hide chats) ---
    func hideConversation(conversationID: String, userID: String) async throws {
        print("ChatManager: Hiding conversation \(conversationID) for user \(userID)")
        try await conversationsCollection.document(conversationID).updateData([
            "hiddenFor": FieldValue.arrayUnion([userID])
        ])
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

    @MainActor
    func listenForConnectionStatus(currentUser: AppUser, otherUser: AppUser) {
        guard let currentUserID = currentUser.id, let otherUserID = otherUser.id else {
            self.isConnectionActive = false
            return
        }
        
        statusListener?.remove() // Remove old one
        
        let (studentID, instructorID) = (currentUser.role == .student) ?
            (currentUserID, otherUserID) : (otherUserID, currentUserID)
            
        let deniedOrBlockedStatuses = [RequestStatus.blocked.rawValue, RequestStatus.denied.rawValue]
        
        let query = requestsCollection
            .whereField("studentID", isEqualTo: studentID)
            .whereField("instructorID", isEqualTo: instructorID)
            .whereField("status", in: deniedOrBlockedStatuses)
            .limit(to: 1)
        
        self.statusListener = query.addSnapshotListener { snapshot, error in
            if let error {
                print("Error listening for connection status: \(error.localizedDescription)")
                self.isConnectionActive = true
                return
            }
            
            if let documents = snapshot?.documents, !documents.isEmpty {
                print("!!! ChatManager Status: Connection is DENIED or BLOCKED.")
                self.isConnectionActive = false
            } else {
                print("ChatManager Status: Connection is Active.")
                self.isConnectionActive = true
            }
        }
    }
    
    func sendMessage(conversationID: String, senderID: String, text: String) async throws {
        guard isConnectionActive else {
            print("!!! ChatManager: sendMessage blocked. Connection is not active.")
            throw ChatError.blocked
        }
        
        let message = ChatMessage(senderID: senderID, text: text)
        
        // 1. Add the new message
        try await conversationsCollection.document(conversationID)
            .collection("messages")
            .addDocument(from: message)
            
        // 2. Find the recipient's ID
        let convoDoc = try await conversationsCollection.document(conversationID).getDocument()
        let participantIDs = convoDoc.data()?["participantIDs"] as? [String] ?? []
        let recipientID = participantIDs.first { $0 != senderID }
        
        // 3. Update the conversation document
        var dataToUpdate: [String: Any] = [
            "lastMessage": text,
            "lastMessageTimestamp": FieldValue.serverTimestamp()
        ]
        
        if let recipientID {
            // This pulls the recipient's ID out of the 'hiddenFor' array
            dataToUpdate["hiddenFor"] = FieldValue.arrayRemove([recipientID])
        }
        
        try await conversationsCollection.document(conversationID).updateData(dataToUpdate)
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
        
        let (studentID, instructorID) = (currentUser.role == .student) ?
            (currentUserID, otherUserID) : (otherUserID, currentUserID)

        let deniedOrBlockedStatuses = [RequestStatus.blocked.rawValue, RequestStatus.denied.rawValue]

        let blockQuery = try await requestsCollection
            .whereField("studentID", isEqualTo: studentID)
            .whereField("instructorID", isEqualTo: instructorID)
            .whereField("status", in: deniedOrBlockedStatuses)
            .limit(to: 1)
            .getDocuments()

        if !blockQuery.isEmpty {
            print("!!! ChatManager: Blocked or Denied. Chat cannot be initiated.")
            throw ChatError.blocked
        }
        
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
        var newConversation = Conversation( // <-- Make it a 'var'
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
            lastMessageTimestamp: Date(),
            hiddenFor: []
        )
        
        // This 'addDocument' call writes to the server
        let newDocRef = try conversationsCollection.addDocument(from: newConversation)
        
        // --- *** THIS IS THE FIX *** ---
        // We don't need to read the document back.
        // We already have the data. Just assign the new ID and return it.
        // This avoids the "Missing permissions" read error.
        newConversation.id = newDocRef.documentID
        return newConversation
        // --- *** END OF FIX *** ---
    }

    
    // MARK: - Cleanup
    
    func removeAllListeners() {
        conversationsListener?.remove()
        messagesListener?.remove()
        statusListener?.remove()
        
        conversationsListener = nil
        messagesListener = nil
        statusListener = nil
        
        self.conversations = []
        self.messages = []
        
        self.isConnectionActive = true
    }
}
