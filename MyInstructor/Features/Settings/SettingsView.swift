import SwiftUI
import UniformTypeIdentifiers

struct SettingsView: View {
    @EnvironmentObject var authManager: AuthManager
    // Uses BackupManager.shared directly (Singleton)
    
    // App Preferences
    @State private var isLocationSharingEnabled = true
    @State private var receiveLessonReminders = true
    @State private var receiveCommunityAlerts = true
    @State private var isPrivacyConsentShowing = false
    
    // Profile Privacy Settings
    @State private var isProfilePrivate = false
    @State private var hideFollowers = false
    @State private var hideEmail = false
    
    // Danger Zone State
    @State private var showDeleteConfirmation = false
    @State private var isDeleting = false
    @State private var password = ""
    
    // Export/Import State
    @State private var isExporting = false
    @State private var isImporting = false
    @State private var showShareSheet = false
    @State private var exportURL: URL?
    @State private var showImportPicker = false
    @State private var alertMessage: String?
    @State private var showAlert = false
    
    // Dummy Data State
    @State private var showDummyConfirmation = false
    @State private var isGeneratingDummyData = false
    
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
                    
                    Toggle("Hide Follower & Following Counts", isOn: $hideFollowers)
                        .tint(.primaryBlue)
                        .onChange(of: hideFollowers) { _ in savePrivacySettings() }
                    
                    Toggle("Hide Email Address", isOn: $hideEmail)
                        .tint(.primaryBlue)
                        .onChange(of: hideEmail) { _ in savePrivacySettings() }
                }
                
                // MARK: - Data Management
                Section("Data Management") {
                    Button {
                        performExport()
                    } label: {
                        HStack {
                            Label("Export Data", systemImage: "square.and.arrow.up")
                            Spacer()
                            if isExporting { ProgressView() }
                        }
                    }
                    .foregroundColor(.primary)
                    .disabled(isExporting)
                    
                    Button {
                        showImportPicker = true
                    } label: {
                        HStack {
                            Label("Import Data", systemImage: "square.and.arrow.down")
                            Spacer()
                            if isImporting { ProgressView() }
                        }
                    }
                    .foregroundColor(.primary)
                    .disabled(isImporting)
                }
                
                // MARK: - Developer Tools (Instructors Only)
                if isInstructor {
                    Section("Developer Tools") {
                        Button {
                            showDummyConfirmation = true
                        } label: {
                            HStack {
                                Label("Generate Dummy Data", systemImage: "wand.and.stars")
                                Spacer()
                                if isGeneratingDummyData { ProgressView() }
                            }
                        }
                        .foregroundColor(.primaryBlue)
                        .disabled(isGeneratingDummyData)
                    }
                }
                
                // MARK: - Account Actions (Bottom)
                Section {
                    Button(role: .destructive) {
                        try? authManager.logout()
                    } label: {
                        Label("Logout", systemImage: "rectangle.portrait.and.arrow.right")
                    }
                    
                    Button(role: .destructive) {
                        password = "" // Reset password field
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
                    Text("Deleting your account removes your public profile, community posts, and personal data. Instructors may retain lesson records for their analysis.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.top, 5)
                }
            }
            .navigationTitle("Settings")
            .sheet(isPresented: $isPrivacyConsentShowing) {
                PrivacyConsentPopup(isLocationSharingEnabled: $isLocationSharingEnabled)
            }
            .sheet(isPresented: $showShareSheet) {
                if let url = exportURL {
                    ShareSheet(activityItems: [url])
                }
            }
            .fileImporter(
                isPresented: $showImportPicker,
                allowedContentTypes: [.json],
                allowsMultipleSelection: false
            ) { result in
                handleImport(result)
            }
            .alert(alertMessage ?? "Error", isPresented: $showAlert) {
                Button("OK", role: .cancel) { }
            }
            .onAppear {
                if let user = authManager.user {
                    self.isProfilePrivate = user.isPrivate ?? false
                    self.hideFollowers = user.hideFollowers ?? false
                    self.hideEmail = user.hideEmail ?? false
                }
            }
            // Account Deletion Alert
            .alert("Delete Account", isPresented: $showDeleteConfirmation) {
                SecureField("Enter Password", text: $password)
                Button("Cancel", role: .cancel) { }
                Button("Delete", role: .destructive) {
                    performAccountDeletion()
                }
            } message: {
                Text("Please enter your password to confirm. This action will permanently delete your profile and community posts.")
            }
            // Dummy Data Confirmation Alert
            .alert("Generate Dummy Data?", isPresented: $showDummyConfirmation) {
                Button("Cancel", role: .cancel) { }
                Button("Generate", role: .destructive) {
                    performDummyDataGeneration()
                }
            } message: {
                Text("This will add sample students, lessons, expenses, and vehicles to your account. This cannot be easily undone.")
            }
        }
    }
    
    // MARK: - Actions
    
    private func performDummyDataGeneration() {
        guard let userID = authManager.user?.id else { return }
        isGeneratingDummyData = true
        
        Task {
            do {
                try await DummyDataManager.shared.generateDummyData(for: userID)
                await MainActor.run {
                    self.isGeneratingDummyData = false
                    self.alertMessage = "Dummy data generated successfully! Pull to refresh your dashboards."
                    self.showAlert = true
                }
            } catch {
                await MainActor.run {
                    self.isGeneratingDummyData = false
                    self.alertMessage = "Failed to generate data: \(error.localizedDescription)"
                    self.showAlert = true
                }
            }
        }
    }
    
    private func performExport() {
        guard let userID = authManager.user?.id else { return }
        isExporting = true
        
        Task {
            do {
                let data = try await BackupManager.shared.createBackupData(for: userID)
                
                // --- FIXED: Use a safe DateFormatter to avoid slashes in filename ---
                let formatter = DateFormatter()
                formatter.dateFormat = "yyyy-MM-dd_HH-mm"
                let dateString = formatter.string(from: Date())
                let fileName = "MyInstructor_Backup_\(dateString).json"
                
                let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
                try data.write(to: tempURL)
                
                await MainActor.run {
                    self.exportURL = tempURL
                    self.isExporting = false
                    self.showShareSheet = true
                }
            } catch {
                await MainActor.run {
                    self.alertMessage = "Export Failed: \(error.localizedDescription)"
                    self.showAlert = true
                    self.isExporting = false
                }
            }
        }
    }
    
    private func handleImport(_ result: Result<[URL], Error>) {
        guard let userID = authManager.user?.id else { return }
        
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }
            
            // Security: access security scoped resource
            guard url.startAccessingSecurityScopedResource() else {
                self.alertMessage = "Permission denied to access the file."
                self.showAlert = true
                return
            }
            
            defer { url.stopAccessingSecurityScopedResource() }
            
            isImporting = true
            Task {
                do {
                    try await BackupManager.shared.restoreBackup(from: url, for: userID)
                    await MainActor.run {
                        self.alertMessage = "Data imported successfully!"
                        self.showAlert = true
                        self.isImporting = false
                    }
                } catch {
                    await MainActor.run {
                        self.alertMessage = "Import Failed: \(error.localizedDescription)"
                        self.showAlert = true
                        self.isImporting = false
                    }
                }
            }
            
        case .failure(let error):
            self.alertMessage = "Import error: \(error.localizedDescription)"
            self.showAlert = true
        }
    }
    
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
        guard !password.isEmpty else { return }
        
        isDeleting = true
        Task {
            do {
                try await authManager.deleteAccount(password: password)
            } catch {
                print("Error deleting account: \(error.localizedDescription)")
                isDeleting = false
            }
        }
    }
}

// Helper for Share Sheet
struct ShareSheet: UIViewControllerRepresentable {
    var activityItems: [Any]
    var applicationActivities: [UIActivity]? = nil

    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(activityItems: activityItems, applicationActivities: applicationActivities)
        return controller
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
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
