// File: MyInstructor/Core/Managers/ChatManager.swift
// --- UPDATED: Replaced faulty query with a robust one that does not require a composite index ---

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
    @Published var isConnectionActive: Bool = true // Start as true, let listener correct it
    
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
    
    func hideConversation(conversationID: String, userID: String) async throws {
        print("ChatManager: Hiding conversation \(conversationID) for user \(userID)")
        try await conversationsCollection.document(conversationID).updateData([
            "hiddenFor": FieldValue.arrayUnion([userID])
        ])
    }
    
    @MainActor
    func markConversationAsRead(_ conversation: Conversation, currentUserID: String) async {
        guard let conversationID = conversation.id else { return }
        
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

    // --- *** THIS IS THE UPDATED FUNCTION *** ---
    @MainActor
    func listenForConnectionStatus(currentUser: AppUser, otherUser: AppUser) {
        guard let currentUserID = currentUser.id, let otherUserID = otherUser.id else {
            self.isConnectionActive = false
            return
        }
        
        statusListener?.remove() // Remove old one
        
        let (studentID, instructorID) = (currentUser.role == .student) ?
            (currentUserID, otherUserID) : (otherUserID, currentUserID)
            
        // --- *** THIS IS THE NEW, ROBUST QUERY *** ---
        // We fetch ALL requests between the two users.
        // This query does NOT require a composite index and will not fail.
        let query = requestsCollection
            .whereField("studentID", isEqualTo: studentID)
            .whereField("instructorID", isEqualTo: instructorID)
        
        self.statusListener = query.addSnapshotListener { snapshot, error in
            if let error {
                print("Error listening for connection status: \(error.localizedDescription)")
                self.isConnectionActive = false // Default to false on error
                return
            }
            
            guard let documents = snapshot?.documents, !documents.isEmpty else {
                // No request document exists at all. Connection is INACTIVE.
                print("!!! ChatManager Status: Connection is INACTIVE (No request found).")
                self.isConnectionActive = false
                return
            }

            // --- *** THIS IS THE FIXED LOGIC *** ---
            // We have the documents. Now we sort them in code to find the newest.
            let requests = documents.compactMap { try? $0.data(as: StudentRequest.self) }
            let newestRequest = requests.sorted(by: { $0.timestamp > $1.timestamp }).first
            
            if let newestRequest = newestRequest, newestRequest.status == .approved {
                // The newest request is "approved". The connection is LIVE.
                print("ChatManager Status: Connection is Active (Approved).")
                self.isConnectionActive = true
            } else {
                // The newest request is "pending", "denied", "blocked", or nil.
                // In all these cases, the connection is NOT LIVE.
                print("!!! ChatManager Status: Connection is INACTIVE (Newest request is \(newestRequest?.status.rawValue ?? "unknown")).")
                self.isConnectionActive = false
            }
            // --- *** END OF FIXED LOGIC *** ---
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
            "lastMessageTimestamp": FieldValue.serverTimestamp(),
            "lastMessageSenderID": senderID, // Set who sent the last message
            "unreadCount": FieldValue.increment(1.0) // Increment the unread count
        ]
        
        // Un-hide the conversation for both sender and recipient
        if let recipientID {
            dataToUpdate["hiddenFor"] = FieldValue.arrayRemove([senderID, recipientID])
        } else {
            dataToUpdate["hiddenFor"] = FieldValue.arrayRemove([senderID])
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

    // --- *** THIS IS THE UPDATED FUNCTION *** ---
    func getOrCreateConversation(currentUser: AppUser, otherUser: AppUser) async throws -> Conversation {
        guard let currentUserID = currentUser.id, let otherUserID = otherUser.id else {
            throw NSError(domain: "ChatManager", code: 0, userInfo: [NSLocalizedDescriptionKey: "Invalid user IDs"])
        }
        
        let (studentID, instructorID) = (currentUser.role == .student) ?
            (currentUserID, otherUserID) : (otherUserID, currentUserID)

        // --- *** THIS IS THE NEW, ROBUST QUERY *** ---
        // 1. Fetch ALL requests between them.
        let query = requestsCollection
            .whereField("studentID", isEqualTo: studentID)
            .whereField("instructorID", isEqualTo: instructorID)
        
        let snapshot = try await query.getDocuments()
        
        // 2. Sort in code to find the newest one.
        let requests = snapshot.documents.compactMap { try? $0.data(as: StudentRequest.self) }
        let newestRequest = requests.sorted(by: { $0.timestamp > $1.timestamp }).first
        
        // 3. Check the status of the newest request.
        if let newestRequest = newestRequest {
            if newestRequest.status != .approved {
                // The newest request is NOT approved (pending, denied, blocked).
                print("!!! ChatManager: Connection not approved (Status: \(newestRequest.status.rawValue)). Chat cannot be initiated.")
                throw ChatError.blocked
            }
            // If we are here, the newest request IS approved.
            
        } else {
            // No request has *ever* existed between them. They cannot chat.
            print("!!! ChatManager: No request found. Chat cannot be initiated.")
            throw ChatError.blocked
        }
        // --- *** END OF NEW LOGIC *** ---
        
        // --- IF WE REACH THIS POINT, THE CHAT IS APPROVED ---
        
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
        
        // 5. No conversation exists. Create a new one.
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
