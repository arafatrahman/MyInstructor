// File: arafatrahman/myinstructor/MyInstructor-main/MyInstructor/Features/Vault/DigitalVaultView.swift
// --- UPDATED FILE: Added PDF Support & Viewer ---

import SwiftUI
import UIKit
import PDFKit
import UniformTypeIdentifiers

struct DigitalVaultView: View {
    @EnvironmentObject var authManager: AuthManager
    @EnvironmentObject var dataService: DataService
    @Environment(\.dismiss) var dismiss

    @State private var documents: [VaultDocument] = []
    @State private var isLoading = true
    
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
            }
            .navigationTitle("Digital Vault")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Back") { dismiss() }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showActionSheet = true
                    } label: {
                        Image(systemName: "plus")
                            .font(.headline)
                            .foregroundColor(.primaryBlue)
                    }
                }
            }
            .task {
                await fetchData()
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
                        if doc.fileType != "pdf" { // For PDF, we might want full screen, so hide this or overlay it
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
    
    // Updated to handle generic file data
    private func uploadFile(data: Data, mimeType: String, title: String) async {
        guard let id = authManager.user?.id else { return }
        
        isUploading = true
        do {
            // 1. Upload to Storage
            let url = try await StorageManager.shared.uploadVaultDocument(fileData: data, userID: id, contentType: mimeType)
            
            // 2. Create Metadata Record
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
            
            // 3. Save to Firestore
            try await dataService.addVaultDocument(newDoc)
            
            await fetchData()
        } catch {
            print("Upload failed: \(error)")
        }
        isUploading = false
        // Cleanup
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

// MARK: - Row View
struct VaultDocumentRow: View {
    let doc: VaultDocument
    
    var isPdf: Bool { doc.fileType == "pdf" }
    
    var body: some View {
        HStack(spacing: 15) {
            ZStack {
                Rectangle().fill(Color(.systemGray6)).frame(width: 50, height: 60).cornerRadius(8)
                // Different Icon for PDF
                Image(systemName: isPdf ? "doc.text.fill" : "doc.text.image.fill")
                    .foregroundColor(isPdf ? .red : .secondary)
                    .font(.title2)
            }
            
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
