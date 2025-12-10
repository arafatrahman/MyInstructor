// File: arafatrahman/myinstructor/MyInstructor-main/MyInstructor/Features/Settings/SettingsView.swift
// --- UPDATED: Renamed Toggle Label & Organized Privacy Section ---

import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var authManager: AuthManager
    
    // App Preferences
    @State private var isLocationSharingEnabled = true
    @State private var receiveLessonReminders = true
    @State private var receiveCommunityAlerts = true
    @State private var isProgressPublic = false
    @State private var isPrivacyConsentShowing = false
    
    // Profile Privacy Settings
    @State private var isProfilePrivate = false
    @State private var hideFollowers = false
    @State private var hideEmail = false
    
    // Danger Zone State
    @State private var showDeleteConfirmation = false
    @State private var isDeleting = false
    
    var isInstructor: Bool {
        authManager.role == .instructor
    }

    var body: some View {
        NavigationView {
            Form {
                
                // MARK: - App Preferences
                Section("Preferences") {
                    Toggle("Enable Live Location", isOn: $isLocationSharingEnabled)
                        .tint(.primaryBlue)
                        .onChange(of: isLocationSharingEnabled) { newValue in
                            if newValue { isPrivacyConsentShowing = true }
                        }
                    
                    if isInstructor {
                        Toggle("Auto-Share Pickup", isOn: .constant(true)).tint(.primaryBlue)
                    }
                    
                    Toggle("Public Progress", isOn: $isProgressPublic).tint(.primaryBlue)
                    Toggle("Lesson Reminders", isOn: $receiveLessonReminders).tint(.primaryBlue)
                    Toggle("Community Alerts", isOn: $receiveCommunityAlerts).tint(.primaryBlue)
                }
                
                // MARK: - Profile Privacy Settings
                Section("Profile Privacy") {
                    Toggle("Private Profile", isOn: $isProfilePrivate)
                        .tint(.primaryBlue)
                        .onChange(of: isProfilePrivate) { _ in savePrivacySettings() }
                    
                    if isProfilePrivate {
                        Text("Only approved followers can see your posts and details.")
                            .font(.caption).foregroundColor(.secondary)
                    }
                    
                    // --- UPDATED LABEL ---
                    Toggle("Hide Follower & Following Counts", isOn: $hideFollowers)
                        .tint(.primaryBlue)
                        .onChange(of: hideFollowers) { _ in savePrivacySettings() }
                    
                    Toggle("Hide Email Address", isOn: $hideEmail)
                        .tint(.primaryBlue)
                        .onChange(of: hideEmail) { _ in savePrivacySettings() }
                }
                
                // MARK: - Account Actions (Bottom)
                Section {
                    Button {
                        // Export Logic
                        print("Export Data Requested")
                    } label: {
                        Label("Export My Data", systemImage: "square.and.arrow.up")
                    }
                    .foregroundColor(.primary)
                    
                    Button(role: .destructive) {
                        try? authManager.logout()
                    } label: {
                        Label("Logout", systemImage: "rectangle.portrait.and.arrow.right")
                    }
                    
                    Button(role: .destructive) {
                        showDeleteConfirmation = true
                    } label: {
                        if isDeleting {
                            ProgressView().tint(.red)
                        } else {
                            Label("Delete Account", systemImage: "trash")
                        }
                    }
                } header: {
                    Text("Account")
                } footer: {
                    Text("Deleting your account removes your public profile and personal data. Instructors may retain lesson records for their analysis.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.top, 5)
                }
            }
            .navigationTitle("Settings")
            .sheet(isPresented: $isPrivacyConsentShowing) {
                PrivacyConsentPopup(isLocationSharingEnabled: $isLocationSharingEnabled)
            }
            .onAppear {
                if let user = authManager.user {
                    self.isProfilePrivate = user.isPrivate ?? false
                    self.hideFollowers = user.hideFollowers ?? false
                    self.hideEmail = user.hideEmail ?? false
                }
            }
            .alert("Delete Account?", isPresented: $showDeleteConfirmation) {
                Button("Cancel", role: .cancel) { }
                Button("Delete", role: .destructive) {
                    performAccountDeletion()
                }
            } message: {
                Text("Are you sure? This will permanently delete your profile. Your lesson history will remain visible to your instructors/students for record-keeping.")
            }
        }
    }
    
    // MARK: - Actions
    
    private func savePrivacySettings() {
        Task {
            try? await authManager.updatePrivacySettings(
                isPrivate: isProfilePrivate,
                hideFollowers: hideFollowers,
                hideEmail: hideEmail
            )
        }
    }
    
    private func performAccountDeletion() {
        isDeleting = true
        Task {
            do {
                try await authManager.deleteAccount()
            } catch {
                print("Error deleting account: \(error.localizedDescription)")
                isDeleting = false
            }
        }
    }
}

struct PrivacyConsentPopup: View {
    @Environment(\.dismiss) var dismiss
    @Binding var isLocationSharingEnabled: Bool
    
    var body: some View {
        VStack(spacing: 25) {
            Image(systemName: "location.fill.viewfinder")
                .font(.system(size: 60))
                .foregroundColor(.primaryBlue)
            Text("Live Location Consent").font(.largeTitle).bold()
            Text("Location is shared only during active lessons.").multilineTextAlignment(.center).padding(.horizontal)
            Button("Allow") { isLocationSharingEnabled = true; dismiss() }.buttonStyle(.primaryDrivingApp)
        }.padding(30)
    }
}
