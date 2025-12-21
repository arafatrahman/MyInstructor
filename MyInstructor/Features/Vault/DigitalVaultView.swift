import SwiftUI
import UIKit
import PDFKit
import UniformTypeIdentifiers
import LocalAuthentication

struct DigitalVaultView: View {
    @EnvironmentObject var authManager: AuthManager
    @EnvironmentObject var dataService: DataService
    @Environment(\.dismiss) var dismiss

    @State private var documents: [VaultDocument] = []
    @State private var isLoading = false
    
    // Security States
    @State private var isUnlocked = false
    @State private var authError: String? = nil
    
    // Picker States
    @State private var showActionSheet = false
    @State private var showImagePicker = false
    @State private var showDocumentPicker = false
    
    @State private var uploadStatus = ""
    @State private var isUploading = false
    
    // Naming States
    @State private var showNamePrompt = false
    @State private var newDocumentName = ""
    @State private var tempFileData: Data?
    @State private var tempMimeType: String = ""
    
    // Viewer State
    @State private var selectedDocument: VaultDocument?

    var body: some View {
        NavigationView {
            ZStack {
                Color(.systemGroupedBackground).ignoresSafeArea()
                
                if isUnlocked {
                    // --- Unlocked Content ---
                    VStack {
                        if isLoading {
                            Spacer()
                            ProgressView("Accessing Vault...")
                            Spacer()
                        } else if documents.isEmpty {
                            Spacer()
                            EmptyStateView(
                                icon: "lock.shield",
                                message: "Your Vault is Empty.",
                                actionTitle: "Upload Document",
                                action: { showActionSheet = true }
                            )
                            Spacer()
                        } else {
                            List {
                                ForEach(documents) { doc in
                                    Button {
                                        selectedDocument = doc
                                    } label: {
                                        VaultDocumentRow(doc: doc)
                                    }
                                    .listRowSeparator(.hidden)
                                    .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                                    .buttonStyle(.plain)
                                    .swipeActions(edge: .trailing) {
                                        Button(role: .destructive) {
                                            Task { await deleteDocument(doc) }
                                        } label: {
                                            Label("Destroy", systemImage: "trash.fill")
                                        }
                                    }
                                }
                            }
                            .listStyle(.plain)
                        }
                        
                        if isUploading {
                            HStack {
                                ProgressView()
                                Text("Encrypting & Uploading...").font(.caption)
                            }
                            .padding()
                            .background(Material.regular)
                            .cornerRadius(20)
                            .padding(.bottom)
                        }
                    }
                } else {
                    // --- Locked View ---
                    VStack(spacing: 25) {
                        Spacer()
                        
                        ZStack {
                            Circle()
                                .fill(Color.primaryBlue.opacity(0.1))
                                .frame(width: 120, height: 120)
                            Image(systemName: "lock.fill")
                                .font(.system(size: 50))
                                .foregroundColor(.primaryBlue)
                        }
                        
                        VStack(spacing: 8) {
                            Text("Vault Locked")
                                .font(.title2)
                                .fontWeight(.bold)
                            Text("Your documents are secured.\nAuthenticate to access them.")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                        }
                        
                        Button {
                            authenticate()
                        } label: {
                            HStack {
                                Image(systemName: "faceid")
                                Text("Unlock Vault")
                            }
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 54)
                            .background(Color.primaryBlue)
                            .cornerRadius(14)
                            .padding(.horizontal, 40)
                        }
                        .padding(.top, 10)
                        
                        if let error = authError {
                            Text(error)
                                .font(.caption)
                                .foregroundColor(.red)
                                .padding(.horizontal)
                                .multilineTextAlignment(.center)
                        }
                        
                        Spacer()
                    }
                }
            }
            .navigationTitle("Digital Vault")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Back") { dismiss() }
                }
                ToolbarItem(placement: .primaryAction) {
                    // Only show Add button if unlocked
                    if isUnlocked {
                        Button {
                            showActionSheet = true
                        } label: {
                            Image(systemName: "plus")
                                .font(.headline)
                                .foregroundColor(.primaryBlue)
                        }
                    }
                }
            }
            .onAppear {
                authenticate()
            }
            // --- Selection Menu ---
            .confirmationDialog("Upload Document", isPresented: $showActionSheet) {
                Button("Photo Library") { showImagePicker = true }
                Button("Files (PDF)") { showDocumentPicker = true }
                Button("Cancel", role: .cancel) { }
            }
            // --- Image Picker ---
            .sheet(isPresented: $showImagePicker) {
                VaultImagePicker { image in
                    if let data = image.jpegData(compressionQuality: 0.8) {
                        self.tempFileData = data
                        self.tempMimeType = "image/jpeg"
                        self.newDocumentName = ""
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                            self.showNamePrompt = true
                        }
                    }
                }
            }
            // --- Document Picker (PDF) ---
            .sheet(isPresented: $showDocumentPicker) {
                VaultDocumentPicker { url in
                    if let data = try? Data(contentsOf: url) {
                        self.tempFileData = data
                        self.tempMimeType = "application/pdf"
                        // Pre-fill name with filename
                        self.newDocumentName = url.deletingPathExtension().lastPathComponent
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                            self.showNamePrompt = true
                        }
                    }
                }
            }
            // --- Name Alert ---
            .alert("Name Document", isPresented: $showNamePrompt) {
                TextField("Document Name", text: $newDocumentName)
                Button("Upload") {
                    if let data = tempFileData {
                        let finalName = newDocumentName.isEmpty ? "Document \(Date().formatted(date: .numeric, time: .omitted))" : newDocumentName
                        Task { await uploadFile(data: data, mimeType: tempMimeType, title: finalName) }
                    }
                }
                Button("Cancel", role: .cancel) {
                    tempFileData = nil
                }
            } message: {
                Text("Enter a name for this secure document.")
            }
            // --- Viewer Sheet ---
            .sheet(item: $selectedDocument) { doc in
                NavigationView {
                    VStack {
                        if doc.fileType == "pdf" {
                            // PDF Viewer
                            if let url = URL(string: doc.url) {
                                PDFKitView(url: url)
                                    .edgesIgnoringSafeArea(.bottom)
                            } else {
                                Text("Invalid URL").foregroundColor(.secondary)
                            }
                        } else {
                            // Image Viewer
                            AsyncImage(url: URL(string: doc.url)) { phase in
                                switch phase {
                                case .empty: ProgressView()
                                case .success(let image): image.resizable().scaledToFit()
                                case .failure: Image(systemName: "exclamationmark.triangle").font(.largeTitle)
                                @unknown default: EmptyView()
                                }
                            }
                            .padding()
                        }
                        
                        // Metadata Footer
                        if doc.fileType != "pdf" {
                            VStack(alignment: .leading, spacing: 10) {
                                Text(doc.title).font(.headline)
                                Text("Added: \(doc.date.formatted())").font(.caption).foregroundColor(.secondary)
                                if doc.isEncrypted {
                                    Label("End-to-End Secure", systemImage: "lock.fill")
                                        .font(.caption)
                                        .foregroundColor(.accentGreen)
                                        .padding(6)
                                        .background(Color.accentGreen.opacity(0.1))
                                        .cornerRadius(6)
                                }
                            }
                            .padding()
                            Spacer()
                        }
                    }
                    .navigationTitle(doc.title)
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .navigationBarLeading) {
                            Button("Close") { selectedDocument = nil }
                        }
                    }
                }
            }
        }
    }
    
    // MARK: - Authentication
    private func authenticate() {
        let context = LAContext()
        var error: NSError?
        
        // deviceOwnerAuthentication allows both Biometrics (FaceID/TouchID) and Passcode
        if context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) {
            let reason = "Unlock your Digital Vault"
            
            context.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: reason) { success, authenticationError in
                DispatchQueue.main.async {
                    if success {
                        self.isUnlocked = true
                        self.authError = nil
                        Task { await fetchData() }
                    } else {
                        self.isUnlocked = false
                        self.authError = authenticationError?.localizedDescription ?? "Authentication failed."
                    }
                }
            }
        } else {
            self.authError = "Please enable Face ID or Passcode in your device settings to use the Vault."
        }
    }
    
    private func fetchData() async {
        guard let id = authManager.user?.id else { return }
        isLoading = true
        do {
            self.documents = try await dataService.fetchVaultDocuments(for: id)
        } catch {
            print("Vault Error: \(error)")
        }
        isLoading = false
    }
    
    private func uploadFile(data: Data, mimeType: String, title: String) async {
        guard let id = authManager.user?.id else { return }
        
        isUploading = true
        do {
            let url = try await StorageManager.shared.uploadVaultDocument(fileData: data, userID: id, contentType: mimeType)
            let fileType = mimeType == "application/pdf" ? "pdf" : "image"
            
            let newDoc = VaultDocument(
                userID: id,
                title: title,
                date: Date(),
                url: url,
                notes: nil,
                fileType: fileType,
                isEncrypted: true
            )
            
            try await dataService.addVaultDocument(newDoc)
            await fetchData()
        } catch {
            print("Upload failed: \(error)")
        }
        isUploading = false
        tempFileData = nil
    }
    
    private func deleteDocument(_ doc: VaultDocument) async {
        guard let id = authManager.user?.id, let docID = doc.id else { return }
        do {
            try await dataService.deleteVaultDocument(userID: id, docID: docID)
            try await StorageManager.shared.deleteMedia(from: doc.url)
            await fetchData()
        } catch {
            print("Delete failed: \(error)")
        }
    }
}

// MARK: - Row View (Updated with Thumbnail)
struct VaultDocumentRow: View {
    let doc: VaultDocument
    
    var isPdf: Bool { doc.fileType == "pdf" }
    
    var body: some View {
        HStack(spacing: 15) {
            // Thumbnail Container
            ZStack {
                if !isPdf, let url = URL(string: doc.url) {
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .success(let image):
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(width: 50, height: 60)
                                .cornerRadius(8)
                                .clipped()
                        case .empty:
                            ProgressView().frame(width: 50, height: 60)
                        case .failure:
                            fallbackIcon
                        @unknown default:
                            fallbackIcon
                        }
                    }
                } else {
                    fallbackIcon
                }
            }
            .frame(width: 50, height: 60)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(doc.title)
                    .font(.headline)
                    .foregroundColor(.primary)
                HStack {
                    if doc.isEncrypted {
                        Image(systemName: "lock.fill").font(.caption2).foregroundColor(.accentGreen)
                    }
                    Text(doc.date.formatted(date: .abbreviated, time: .shortened))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            Image(systemName: "chevron.right").font(.caption).foregroundColor(.secondary.opacity(0.5))
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.03), radius: 4, x: 0, y: 2)
    }
    
    var fallbackIcon: some View {
        ZStack {
            Rectangle().fill(Color(.systemGray6)).frame(width: 50, height: 60).cornerRadius(8)
            Image(systemName: isPdf ? "doc.text.fill" : "doc.text.image.fill")
                .foregroundColor(isPdf ? .red : .secondary)
                .font(.title2)
        }
    }
}

// MARK: - Helper: Image Picker
struct VaultImagePicker: UIViewControllerRepresentable {
    @Environment(\.presentationMode) var presentationMode
    let onImagePicked: (UIImage) -> Void
    
    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.delegate = context.coordinator
        picker.sourceType = .photoLibrary
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, UINavigationControllerDelegate, UIImagePickerControllerDelegate {
        let parent: VaultImagePicker
        init(_ parent: VaultImagePicker) { self.parent = parent }
        
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            if let image = info[.originalImage] as? UIImage {
                parent.onImagePicked(image)
            }
            parent.presentationMode.wrappedValue.dismiss()
        }
    }
}

// MARK: - Helper: Document Picker (PDF)
struct VaultDocumentPicker: UIViewControllerRepresentable {
    @Environment(\.presentationMode) var presentationMode
    let onPick: (URL) -> Void

    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: [.pdf], asCopy: true)
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    class Coordinator: NSObject, UIDocumentPickerDelegate {
        let parent: VaultDocumentPicker
        init(_ parent: VaultDocumentPicker) { self.parent = parent }

        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            if let url = urls.first {
                parent.onPick(url)
            }
        }
    }
}

// MARK: - Helper: PDF Viewer
struct PDFKitView: UIViewRepresentable {
    let url: URL
    
    func makeUIView(context: Context) -> PDFView {
        let pdfView = PDFView()
        pdfView.autoScales = true
        return pdfView
    }
    
    func updateUIView(_ uiView: PDFView, context: Context) {
        if uiView.document?.documentURL != url {
            uiView.document = PDFDocument(url: url)
        }
    }
}
