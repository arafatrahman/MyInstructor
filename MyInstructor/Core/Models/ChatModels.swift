// File: MyInstructor/Core/Models/ChatModels.swift
// --- UPDATED: Added isEdited and isDeleted flags ---

import Foundation
import FirebaseFirestore

// This document stores the high-level chat
struct Conversation: Identifiable, Codable, Hashable {
    @DocumentID var id: String?
    
    // Stores the two user IDs (student and instructor)
    let participantIDs: [String]
    
    // Store participant info for easy display
    var participantNames: [String: String]
    var participantPhotoURLs: [String: String?]

    // For the conversation list preview
    var lastMessage: String?
    var lastMessageTimestamp: Date?
    var unreadCount: Int = 0 // You can implement this later
}

// This document is for an individual message
// It will be in a sub-collection: /conversations/{id}/messages
struct ChatMessage: Identifiable, Codable, Hashable {
    @DocumentID var id: String?
    
    let senderID: String
    var text: String // Changed to 'var' so it can be updated
    @ServerTimestamp var timestamp: Date?
    
    // --- NEWLY ADDED FLAGS ---
    var isEdited: Bool? = false
    var isDeleted: Bool? = false
}
