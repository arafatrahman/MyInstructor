// File: ChatLoadingView.swift
// (This is a NEW file. Place it in your project)

import SwiftUI

struct ChatLoadingView: View {
    @EnvironmentObject var authManager: AuthManager
    @EnvironmentObject var chatManager: ChatManager
    
    // The user we want to chat with
    let otherUser: AppUser
    
    @State private var conversation: Conversation? = nil
    @State private var isLoading = true
    
    var body: some View {
        VStack {
            ProgressView("Opening Chat...")
            
            // This NavigationLink is hidden, but it activates
            // as soon as the 'conversation' object is loaded.
            if let conversation {
                NavigationLink(
                    destination: ChatView(conversation: conversation),
                    isActive: .constant(true),
                    label: { EmptyView() }
                )
            }
        }
        .task {
            // When the view appears, find or create the chat
            guard let currentUser = authManager.user else { return }
            
            do {
                self.conversation = try await chatManager.getOrCreateConversation(
                    currentUser: currentUser,
                    otherUser: otherUser
                )
            } catch {
                print("Error getting or creating conversation: \(error)")
                // TODO: Show an error to the user
            }
        }
    }
}
