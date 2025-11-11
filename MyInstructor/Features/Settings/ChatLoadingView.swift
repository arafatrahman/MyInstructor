// File: arafatrahman/myinstructor/MyInstructor-main/MyInstructor/Features/Settings/ChatLoadingView.swift
// --- UPDATED: Now handles errors from ChatManager ---

import SwiftUI

struct ChatLoadingView: View {
    @EnvironmentObject var authManager: AuthManager
    @EnvironmentObject var chatManager: ChatManager
    
    // --- *** ADD THESE LINES *** ---
    @Environment(\.dismiss) var dismiss
    @State private var errorMessage: String? = nil
    @State private var isShowingErrorAlert: Bool = false
    // --- *** END OF ADD *** ---
    
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
            guard let currentUser = authManager.user else {
                self.errorMessage = "You are not logged in."
                self.isShowingErrorAlert = true
                return
            }
            
            do {
                // --- *** UPDATED: Use do-catch *** ---
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
            // --- *** END OF UPDATE *** ---
        }
        // --- *** ADD THIS ALERT MODIFIER *** ---
        .alert("Cannot Open Chat", isPresented: $isShowingErrorAlert, presenting: errorMessage) { _ in
            Button("OK") {
                // When "OK" is tapped, dismiss this loading view
                dismiss()
            }
        } message: { message in
            Text(message)
        }
        // --- *** END OF ADD *** ---
    }
}
