// File: arafatrahman/myinstructor/MyInstructor-main/MyInstructor/Core/Managers/StorageManager.swift
// --- UPDATED: Added uploadVaultDocument ---

import Foundation
import FirebaseStorage
import UIKit
import Combine

class StorageManager: ObservableObject {
    
    static let shared = StorageManager()
    private init() {}
    
    private let storage = Storage.storage()
    private var storageReference: StorageReference {
        storage.reference()
    }
    
    private func profilePhotosReference(userID: String) -> StorageReference {
        storageReference.child("profile_photos").child(userID)
    }

    private func postMediaReference(userID: String) -> StorageReference {
        let mediaID = UUID().uuidString
        return storageReference.child("post_media").child(userID).child("\(mediaID).jpg")
    }
    
    private func vehiclePhotosReference(userID: String) -> StorageReference {
        let mediaID = UUID().uuidString
        return storageReference.child("vehicle_photos").child(userID).child("\(mediaID).jpg")
    }
    
    // --- NEW REFERENCE ---
    private func vaultDocumentsReference(userID: String) -> StorageReference {
        let docID = UUID().uuidString
        // "vault" folder implies secure storage logic in Security Rules
        return storageReference.child("vault").child(userID).child("\(docID).jpg")
    }

    // ... (Existing uploadPostMedia function) ...
    func uploadPostMedia(photoData: Data, userID: String) async throws -> String {
        guard let image = UIImage(data: photoData),
              let compressedJPEGData = image.jpegData(compressionQuality: 0.7) else {
            throw NSError(domain: "StorageManager", code: -2, userInfo: [NSLocalizedDescriptionKey: "Could not compress image."])
        }

        let mediaRef = postMediaReference(userID: userID)
        let metadata = StorageMetadata()
        metadata.contentType = "image/jpeg"
        
        _ = try await mediaRef.putDataAsync(compressedJPEGData, metadata: metadata)
        let downloadURL = try await mediaRef.downloadURL()
        return downloadURL.absoluteString
    }
    
    // ... (Existing uploadVehiclePhoto function) ...
    func uploadVehiclePhoto(photoData: Data, userID: String) async throws -> String {
        print("StorageManager: Uploading vehicle photo...")
        guard let image = UIImage(data: photoData),
              let compressedJPEGData = image.jpegData(compressionQuality: 0.7) else {
            throw NSError(domain: "StorageManager", code: -2, userInfo: [NSLocalizedDescriptionKey: "Could not compress image."])
        }

        let mediaRef = vehiclePhotosReference(userID: userID)
        let metadata = StorageMetadata()
        metadata.contentType = "image/jpeg"
        
        _ = try await mediaRef.putDataAsync(compressedJPEGData, metadata: metadata)
        let downloadURL = try await mediaRef.downloadURL()
        print("StorageManager: Vehicle photo uploaded: \(downloadURL.absoluteString)")
        return downloadURL.absoluteString
    }
    
    // --- NEW FUNCTION: Upload Vault Document ---
    func uploadVaultDocument(photoData: Data, userID: String) async throws -> String {
        print("StorageManager: Uploading to Vault...")
        guard let image = UIImage(data: photoData),
              let compressedJPEGData = image.jpegData(compressionQuality: 0.8) else {
            throw NSError(domain: "StorageManager", code: -2, userInfo: [NSLocalizedDescriptionKey: "Could not compress image."])
        }

        let docRef = vaultDocumentsReference(userID: userID)
        let metadata = StorageMetadata()
        metadata.contentType = "image/jpeg"
        metadata.customMetadata = ["secured": "true"] // Metadata flag for security rules
        
        _ = try await docRef.putDataAsync(compressedJPEGData, metadata: metadata)
        let downloadURL = try await docRef.downloadURL()
        return downloadURL.absoluteString
    }
    
    // ... (Existing deleteMedia function) ...
    func deleteMedia(from urlString: String) async throws {
        let fileRef = storage.reference(forURL: urlString)
        do {
            try await fileRef.delete()
        } catch {
            if let storageError = error as? NSError, storageError.code == StorageErrorCode.objectNotFound.rawValue {
                print("File not found, ignoring.")
            } else {
                throw error
            }
        }
    }

    // ... (Existing uploadProfilePhoto function) ...
    func uploadProfilePhoto(photoData: Data, userID: String) async throws -> String {
        guard let image = UIImage(data: photoData),
              let compressedJPEGData = image.jpegData(compressionQuality: 0.8) else {
            throw NSError(domain: "StorageManager", code: -2, userInfo: [NSLocalizedDescriptionKey: "Image error."])
        }

        let photoRef = profilePhotosReference(userID: userID)
        let metadata = StorageMetadata()
        metadata.contentType = "image/jpeg"
        
        _ = try await photoRef.putDataAsync(compressedJPEGData, metadata: metadata)
        let downloadURL = try await photoRef.downloadURL()
        return downloadURL.absoluteString
    }
}
