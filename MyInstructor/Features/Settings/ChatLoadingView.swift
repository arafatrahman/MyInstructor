// File: arafatrahman/myinstructor/MyInstructor-main/MyInstructor/Features/Settings/ChatLoadingView.swift
// --- UPDATED: Now dismisses itself when returning from ChatView ---

import SwiftUI

struct ChatLoadingView: View {
    @EnvironmentObject var authManager: AuthManager
    @EnvironmentObject var chatManager: ChatManager
    
    @Environment(\.dismiss) var dismiss
    @State private var errorMessage: String? = nil
    @State private var isShowingErrorAlert: Bool = false
    
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
        // --- *** THIS IS THE FIX *** ---
        .onAppear {
            if conversation != nil {
                // If this view re-appears and we *already* have a conversation,
                // it means the user came BACK from ChatView.
                // We should dismiss this loading view entirely and go
                // back to the profile screen.
                dismiss()
            }
        }
        // --- *** END OF FIX *** ---
        .task {
            // --- *** ADDED THIS CHECK *** ---
            // Only run the fetch logic if we haven't already.
            // This prevents a re-fetch when coming back.
            guard conversation == nil else { return }
            
            // When the view appears, find or create the chat
            guard let currentUser = authManager.user else {
                self.errorMessage = "You are not logged in."
                self.isShowingErrorAlert = true
                return
            }
            
            do {
                self.conversation = try await chatManager.getOrCreateConversation(
                    currentUser: currentUser,
                    otherUser: otherUser
                )
            } catch let error as ChatError {
                // This is the ChatError.blocked we expect
                print("ChatLoadingView: Caught chat error: \(error.localizedDescription)")
                self.errorMessage = error.localizedDescription
                self.isShowingErrorAlert = true
            } catch {
                // Any other unexpected error
                print("Error getting or creating conversation: \(error)")
                self.errorMessage = "An unexpected error occurred. Please try again."
                self.isShowingErrorAlert = true
            }
        }
        .alert("Cannot Open Chat", isPresented: $isShowingErrorAlert, presenting: errorMessage) { _ in
            Button("OK") {
                // When "OK" is tapped, dismiss this loading view
                dismiss()
            }
        } message: { message in
            Text(message)
        }
    }
}
