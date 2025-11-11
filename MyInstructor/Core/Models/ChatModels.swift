// File: MyInstructor/Core/Models/ChatModels.swift
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
    var unreadCount: Int = 0
    
    // --- *** THIS IS THE NEW FIELD *** ---
    /// An array of user IDs who have "hidden" or "deleted" this chat from their view.
    var hiddenFor: [String]?
}

// This document is for an individual message
// (This struct remains unchanged)
struct ChatMessage: Identifiable, Codable, Hashable {
    @DocumentID var id: String?
    
    let senderID: String
    var text: String
    @ServerTimestamp var timestamp: Date?
    
    var isEdited: Bool? = false
    var isDeleted: Bool? = false
}

// (This enum remains unchanged)
enum ChatError: Error, LocalizedError {
    case blocked
    
    var errorDescription: String? {
        switch self {
        case .blocked:
            return "This user cannot be messaged."
        }
    }
}
