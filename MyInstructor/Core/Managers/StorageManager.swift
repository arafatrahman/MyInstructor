// File: arafatrahman/myinstructor/MyInstructor-main/MyInstructor/Core/Managers/StorageManager.swift
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
    
    // MARK: - Public Functions
    
    /// Uploads a profile photo and returns the download URL.
    /// - Parameters:
    ///   - photoData: The raw `Data` of the image (in any format, e.g., HEIC, PNG).
    ///   - userID: The ID of the user to associate the image with.
    /// - Returns: A `String` containing the public download URL.
    func uploadProfilePhoto(photoData: Data, userID: String) async throws -> String {
        
        // --- IMAGE CONVERSION ---
        print("StorageManager: Received photo data. Size: \(photoData.count) bytes.") // <-- ADDED
        guard let image = UIImage(data: photoData) else {
            print("!!! StorageManager ERROR: Could not convert data to UIImage.") // <-- ADDED
            throw NSError(domain: "StorageManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "Could not convert data to UIImage."])
        }
        guard let compressedJPEGData = image.jpegData(compressionQuality: 0.8) else {
            print("!!! StorageManager ERROR: Could not compress image to JPEG.") // <-- ADDED
            throw NSError(domain: "StorageManager", code: -2, userInfo: [NSLocalizedDescriptionKey: "Could not compress image to JPEG."])
        }
        print("StorageManager: Image successfully converted to JPEG. Size: \(compressedJPEGData.count) bytes.") // <-- ADDED
        // -------------------------

        let photoRef = profilePhotosReference(userID: userID)
        print("StorageManager: Reference created: \(photoRef.fullPath)") // <-- ADDED

        // --- UPLOAD ---
        let metadata = StorageMetadata()
        metadata.contentType = "image/jpeg" // We now know it's a JPEG
        
        print("StorageManager: Attempting upload to Firebase Storage...") // <-- ADDED
        do {
            // Using putDataAsync which works well with async/await
            let _ = try await photoRef.putDataAsync(compressedJPEGData, metadata: metadata)
            print("StorageManager: Upload Task SUCCESSFUL.") // <-- ADDED
        } catch {
            print("!!! StorageManager FIREBASE UPLOAD FAILED: \(error.localizedDescription)") // <-- ADDED MORE DETAIL
            // Check error code, e.g., storage/unauthorized for rules issues
            let nsError = error as NSError
            print("!!! StorageManager Firebase Error Code: \(nsError.code), Domain: \(nsError.domain)") // <-- ADDED
            throw error // Re-throw the original error
        }
        // -------------

        // --- GET URL ---
        print("StorageManager: Attempting to get download URL...") // <-- ADDED
        do {
            let downloadURL = try await photoRef.downloadURL()
            print("StorageManager: Got download URL: \(downloadURL.absoluteString)") // <-- ADDED
            return downloadURL.absoluteString
        } catch {
            print("!!! StorageManager GET DOWNLOAD URL FAILED: \(error.localizedDescription)") // <-- ADDED
            let nsError = error as NSError
            print("!!! StorageManager Firebase Error Code: \(nsError.code), Domain: \(nsError.domain)") // <-- ADDED
            throw error // Re-throw
        }
        // ------------
    }
}
