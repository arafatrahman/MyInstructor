// File: arafatrahman/myinstructor/MyInstructor-main/MyInstructor/Features/Vault/DigitalVaultView.swift
// --- NEW FILE: Digital Vault for Secure Documents ---

import SwiftUI
import UIKit

struct DigitalVaultView: View {
    @EnvironmentObject var authManager: AuthManager
    @EnvironmentObject var dataService: DataService
    @Environment(\.dismiss) var dismiss

    @State private var documents: [VaultDocument] = []
    @State private var isLoading = true
    @State private var showImagePicker = false
    @State private var uploadStatus = ""
    @State private var isUploading = false
    
    // To present the selected image fullscreen
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
                            action: { showImagePicker = true }
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
                        showImagePicker = true
                    } label: {
                        Image(systemName: "plus.shield.fill")
                            .font(.headline)
                            .foregroundColor(.primaryBlue)
                    }
                }
            }
            .task {
                await fetchData()
            }
            .sheet(isPresented: $showImagePicker) {
                VaultImagePicker { image in
                    Task { await uploadImage(image) }
                }
            }
            // Simple overlay for viewing the document
            .sheet(item: $selectedDocument) { doc in
                NavigationView {
                    VStack {
                        AsyncImage(url: URL(string: doc.url)) { phase in
                            switch phase {
                            case .empty: ProgressView()
                            case .success(let image): image.resizable().scaledToFit()
                            case .failure: Image(systemName: "exclamationmark.triangle").font(.largeTitle)
                            @unknown default: EmptyView()
                            }
                        }
                        .padding()
                        
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
                    .navigationTitle("Secure Viewer")
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
    
    private func uploadImage(_ image: UIImage) async {
        guard let id = authManager.user?.id,
              let data = image.jpegData(compressionQuality: 0.8) else { return }
        
        isUploading = true
        do {
            // 1. Upload to Storage
            let url = try await StorageManager.shared.uploadVaultDocument(photoData: data, userID: id)
            
            // 2. Create Metadata Record
            let newDoc = VaultDocument(
                userID: id,
                title: "Receipt \(Date().formatted(date: .numeric, time: .omitted))",
                date: Date(),
                url: url,
                notes: nil,
                fileType: "image",
                isEncrypted: true
            )
            
            // 3. Save to Firestore
            try await dataService.addVaultDocument(newDoc)
            
            await fetchData()
        } catch {
            print("Upload failed: \(error)")
        }
        isUploading = false
    }
    
    private func deleteDocument(_ doc: VaultDocument) async {
        guard let id = authManager.user?.id, let docID = doc.id else { return }
        do {
            // Delete from Firestore
            try await dataService.deleteVaultDocument(userID: id, docID: docID)
            
            // Delete from Storage
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
    
    var body: some View {
        HStack(spacing: 15) {
            ZStack {
                Rectangle().fill(Color(.systemGray6)).frame(width: 50, height: 60).cornerRadius(8)
                Image(systemName: "doc.text.image.fill")
                    .foregroundColor(.secondary)
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
        picker.sourceType = .photoLibrary // or .camera
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
