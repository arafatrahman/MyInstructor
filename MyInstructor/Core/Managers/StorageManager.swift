// File: arafatrahman/myinstructor/MyInstructor-main/MyInstructor/Core/Managers/StorageManager.swift
// --- UPDATED: Added deleteMedia function ---

import Foundation
import FirebaseStorage
import UIKit
import Combine

// This class will manage all file uploads and downloads
class StorageManager: ObservableObject {
    
    // Create a shared instance to be used by other managers
    static let shared = StorageManager()
    private init() {} // Private initializer for Singleton pattern
    
    private let storage = Storage.storage()
    
    // A reference to the root of our storage
    private var storageReference: StorageReference {
        storage.reference()
    }
    
    // A reference to the 'profile_photos' folder
    private func profilePhotosReference(userID: String) -> StorageReference {
        storageReference.child("profile_photos").child(userID)
    }

    /// A reference to the 'post_media' folder, creating a unique file name
    private func postMediaReference(userID: String) -> StorageReference {
        let mediaID = UUID().uuidString
        return storageReference.child("post_media").child(userID).child("\(mediaID).jpg")
    }

    /// Uploads media for a community post and returns the download URL.
    func uploadPostMedia(photoData: Data, userID: String) async throws -> String {
        
        print("StorageManager: Compressing post media...")
        guard let image = UIImage(data: photoData),
              let compressedJPEGData = image.jpegData(compressionQuality: 0.7) else {
            throw NSError(domain: "StorageManager", code: -2, userInfo: [NSLocalizedDescriptionKey: "Could not compress image to JPEG."])
        }
        print("StorageManager: Post media compressed. Size: \(compressedJPEGData.count) bytes.")

        let mediaRef = postMediaReference(userID: userID) // Get unique ref
        
        let metadata = StorageMetadata()
        metadata.contentType = "image/jpeg"
        
        print("StorageManager: Uploading post media to \(mediaRef.fullPath)...")
        do {
            let _ = try await mediaRef.putDataAsync(compressedJPEGData, metadata: metadata)
            print("StorageManager: Post media upload SUCCESSFUL.")
        } catch {
            print("!!! StorageManager POST MEDIA UPLOAD FAILED: \(error.localizedDescription)")
            throw error
        }
        
        // Get and return the download URL
        do {
            let downloadURL = try await mediaRef.downloadURL()
            print("StorageManager: Got post media URL: \(downloadURL.absoluteString)")
            return downloadURL.absoluteString
        } catch {
            print("!!! StorageManager GET POST MEDIA URL FAILED: \(error.localizedDescription)")
            throw error
        }
    }
    
    // --- *** THIS IS THE NEW FUNCTION *** ---
    /// Deletes a file from Firebase Storage using its download URL.
    func deleteMedia(from urlString: String) async throws {
        // Get a reference to the file from the URL
        let fileRef = storage.reference(forURL: urlString)
        
        do {
            try await fileRef.delete()
            print("StorageManager: Successfully deleted file at \(urlString)")
        } catch {
            // We can choose to ignore "object not found" errors
            if let storageError = error as? NSError, storageError.code == StorageErrorCode.objectNotFound.rawValue {
                print("StorageManager: File not found, likely already deleted. Ignoring.")
            } else {
                print("!!! StorageManager: Error deleting file: \(error.localizedDescription)")
                throw error
            }
        }
    }
    // --- *** END OF NEW FUNCTION *** ---

    // MARK: - Public Functions
    
    /// Uploads a profile photo and returns the download URL.
    /// - Parameters:
    ///   - photoData: The raw `Data` of the image (in any format, e.g., HEIC, PNG).
    ///   - userID: The ID of the user to associate the image with.
    /// - Returns: A `String` containing the public download URL.
    func uploadProfilePhoto(photoData: Data, userID: String) async throws -> String {
        
        // --- IMAGE CONVERSION ---
        print("StorageManager: Received photo data. Size: \(photoData.count) bytes.")
        guard let image = UIImage(data: photoData) else {
            print("!!! StorageManager ERROR: Could not convert data to UIImage.")
            throw NSError(domain: "StorageManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "Could not convert data to UIImage."])
        }
        guard let compressedJPEGData = image.jpegData(compressionQuality: 0.8) else {
            print("!!! StorageManager ERROR: Could not compress image to JPEG.")
            throw NSError(domain: "StorageManager", code: -2, userInfo: [NSLocalizedDescriptionKey: "Could not compress image to JPEG."])
        }
        print("StorageManager: Image successfully converted to JPEG. Size: \(compressedJPEGData.count) bytes.")
        // -------------------------

        let photoRef = profilePhotosReference(userID: userID)
        print("StorageManager: Reference created: \(photoRef.fullPath)")

        // --- UPLOAD ---
        let metadata = StorageMetadata()
        metadata.contentType = "image/jpeg" // We now know it's a JPEG
        
        print("StorageManager: Attempting upload to Firebase Storage...")
        do {
            // Using putDataAsync which works well with async/await
            let _ = try await photoRef.putDataAsync(compressedJPEGData, metadata: metadata)
            print("StorageManager: Upload Task SUCCESSFUL.")
        } catch {
            print("!!! StorageManager FIREBASE UPLOAD FAILED: \(error.localizedDescription)")
            // Check error code, e.g., storage/unauthorized for rules issues
            let nsError = error as NSError
            print("!!! StorageManager Firebase Error Code: \(nsError.code), Domain: \(nsError.domain)")
            throw error // Re-throw the original error
        }
        // -------------

        // --- GET URL ---
        print("StorageManager: Attempting to get download URL...")
        do {
            let downloadURL = try await photoRef.downloadURL()
            print("StorageManager: Got download URL: \(downloadURL.absoluteString)")
            return downloadURL.absoluteString
        } catch {
            print("!!! StorageManager GET DOWNLOAD URL FAILED: \(error.localizedDescription)")
            let nsError = error as NSError
            print("!!! StorageManager Firebase Error Code: \(nsError.code), Domain: \(nsError.domain)")
            throw error // Re-throw
        }
        // ------------
    }
}
