// File: MyInstructor/Core/Managers/ChatManager.swift
// --- UPDATED: Clears related notifications when conversation is read ---

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
        conversationsListener?.remove()
        
        let query = conversationsCollection
            .whereField("participantIDs", arrayContains: userID)
            .order(by: "lastMessageTimestamp", descending: true)
            
        self.conversationsListener = query.addSnapshotListener { snapshot, error in
            if let error {
                print("Error fetching conversations: \(error.localizedDescription)")
                return
            }
            guard let documents = snapshot?.documents else { return }
            
            let allConversations = documents.compactMap { try? $0.data(as: Conversation.self) }
            self.conversations = allConversations.filter { conversation in
                !(conversation.hiddenFor?.contains(userID) ?? false)
            }
            
            print("ChatManager: Fetched \(self.conversations.count) visible conversations")
        }
    }
    
    func hideConversation(conversationID: String, userID: String) async throws {
        print("ChatManager: Hiding conversation \(conversationID) for user \(userID)")
        try await conversationsCollection.document(conversationID).updateData([
            "hiddenFor": FieldValue.arrayUnion([userID])
        ])
    }
    
    @MainActor
    func markConversationAsRead(_ conversation: Conversation, currentUserID: String) async {
        guard let conversationID = conversation.id else { return }
        
        // 1. Mark relevant App Notifications as read
        NotificationManager.shared.markNotificationsAsRead(relatedID: conversationID, userID: currentUserID)
        
        // 2. Update Conversation unread count in Firestore
        if conversation.lastMessageSenderID != currentUserID && conversation.unreadCount > 0 {
            print("ChatManager: Marking conversation \(conversationID) as read in Firestore.")
            do {
                try await conversationsCollection.document(conversationID).updateData([
                    "unreadCount": 0
                ])
            } catch {
                print("Failed to mark as read: \(error.localizedDescription)")
            }
        }
    }
    
    // MARK: - Chat Message View
    
    @MainActor
    func listenForMessages(conversationID: String) {
        messagesListener?.remove()
        
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
        
        statusListener?.remove()
        
        let (studentID, instructorID) = (currentUser.role == .student) ?
            (currentUserID, otherUserID) : (otherUserID, currentUserID)
            
        let query = requestsCollection
            .whereField("studentID", isEqualTo: studentID)
            .whereField("instructorID", isEqualTo: instructorID)
        
        self.statusListener = query.addSnapshotListener { snapshot, error in
            if let error {
                print("Error listening for connection status: \(error.localizedDescription)")
                self.isConnectionActive = false
                return
            }
            
            guard let documents = snapshot?.documents, !documents.isEmpty else {
                print("!!! ChatManager Status: Connection is INACTIVE (No request found).")
                self.isConnectionActive = false
                return
            }

            let requests = documents.compactMap { try? $0.data(as: StudentRequest.self) }
            let newestRequest = requests.sorted(by: { $0.timestamp > $1.timestamp }).first
            
            if let newestRequest = newestRequest, newestRequest.status == .approved {
                print("ChatManager Status: Connection is Active (Approved).")
                self.isConnectionActive = true
            } else {
                print("!!! ChatManager Status: Connection is INACTIVE.")
                self.isConnectionActive = false
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
            
        // 2. Fetch doc to get recipient info
        let convoDoc = try await conversationsCollection.document(conversationID).getDocument()
        guard let data = convoDoc.data() else { return }
        
        let participantIDs = data["participantIDs"] as? [String] ?? []
        let recipientID = participantIDs.first { $0 != senderID }
        
        // 3. Update the conversation document
        var dataToUpdate: [String: Any] = [
            "lastMessage": text,
            "lastMessageTimestamp": FieldValue.serverTimestamp(),
            "lastMessageSenderID": senderID,
            "unreadCount": FieldValue.increment(1.0)
        ]
        
        if let recipientID {
            dataToUpdate["hiddenFor"] = FieldValue.arrayRemove([senderID, recipientID])
        } else {
            dataToUpdate["hiddenFor"] = FieldValue.arrayRemove([senderID])
        }
        
        try await conversationsCollection.document(conversationID).updateData(dataToUpdate)
        
        // 4. Send Notification (With relatedID)
        if let recipientID = recipientID {
            let participantNames = data["participantNames"] as? [String: String] ?? [:]
            let senderName = participantNames[senderID] ?? "User"
            
            NotificationManager.shared.sendNotification(
                to: recipientID,
                title: "New Message from \(senderName)",
                message: text,
                type: "message",
                relatedID: conversationID // Link notification to this conversation
            )
        }
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

        let query = requestsCollection
            .whereField("studentID", isEqualTo: studentID)
            .whereField("instructorID", isEqualTo: instructorID)
        
        let snapshot = try await query.getDocuments()
        
        let requests = snapshot.documents.compactMap { try? $0.data(as: StudentRequest.self) }
        let newestRequest = requests.sorted(by: { $0.timestamp > $1.timestamp }).first
        
        if let newestRequest = newestRequest {
            if newestRequest.status != .approved {
                throw ChatError.blocked
            }
        } else {
            throw ChatError.blocked
        }
        
        let conversationQuery = conversationsCollection
            .whereField("participantIDs", arrayContains: currentUserID)
        
        let conversationSnapshot = try await conversationQuery.getDocuments()
        
        for doc in conversationSnapshot.documents {
            let participantIDs = doc.data()["participantIDs"] as? [String] ?? []
            if participantIDs.contains(otherUserID) {
                print("ChatManager: Found existing conversation.")
                return try doc.data(as: Conversation.self)
            }
        }
        
        print("ChatManager: Creating new conversation...")
        var newConversation = Conversation(
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
            lastMessageSenderID: nil,
            unreadCount: 0,
            hiddenFor: []
        )
        
        let newDocRef = try conversationsCollection.addDocument(from: newConversation)
        newConversation.id = newDocRef.documentID
        return newConversation
    }
    
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
