// File: arafatrahman/myinstructor/MyInstructor-main/MyInstructor/Core/Managers/AuthManager.swift
// --- UPDATED to add 'syncApprovedInstructors' ---

import Combine
import Foundation
import FirebaseAuth
import FirebaseFirestore
import FirebaseStorage
import UIKit

@MainActor // Ensures class runs on the main thread
class AuthManager: ObservableObject {
    // MARK: - Published Properties
    @Published var user: AppUser? = nil
    @Published var isAuthenticated: Bool = false
    @Published var isLoading: Bool = true // Start as true during initialization
    @Published var role: UserRole = .unselected

    // MARK: - Private Properties
    private var authHandle: AuthStateDidChangeListenerHandle?
    private let db = Firestore.firestore()
    private let usersCollection = "users"

    // Flag to prevent race condition ONLY during the active sign-up process
    private var isCurrentlySigningUp = false

    // MARK: - Initialization
    init() {
        self.isLoading = true
        print("AuthManager: Initializing and setting up listener.")
        setupAuthStateListener()
    }

    // MARK: - Auth State Listener
    private func setupAuthStateListener() {
        authHandle = Auth.auth().addStateDidChangeListener { [weak self] auth, firebaseUser in
            Task { @MainActor in
                guard let self = self else { return }
                print("AuthManager Listener: Auth state changed.")

                if let firebaseUser = firebaseUser {
                    print("AuthManager Listener: User is signed in (UID: \(firebaseUser.uid)). Current isCurrentlySigningUp=\(self.isCurrentlySigningUp)")
                    if !self.isCurrentlySigningUp {
                        if !self.isAuthenticated { self.isAuthenticated = true }
                        await self.fetchUserData(id: firebaseUser.uid, email: firebaseUser.email)
                    } else {
                        print("AuthManager Listener: Deferring fetchUserData because signUp is in progress.")
                    }
                } else {
                    print("AuthManager Listener: User is signed out.")
                    self.resetState()
                }
            }
        }
    }

    // MARK: - Data Fetching
    private func fetchUserData(id: String, email: String?) async {
        guard !self.isCurrentlySigningUp else {
            print("FetchUserData: Aborted because signUp is still marked as in progress.")
            return
        }
        print("FetchUserData: Attempting to load user data for UID: \(id)...")
        if !self.isLoading { self.isLoading = true }

        do {
            let document = try await db.collection(usersCollection).document(id).getDocument()
            if document.exists, var appUser = try? document.data(as: AppUser.self) {
                print("FetchUserData: Document found for user \(id). Role: \(appUser.role)")
                self.user = appUser
                self.role = appUser.role
            } else {
                print("FetchUserData: No document found for \(id). Creating new default user profile.")
                let defaultRole: UserRole = .student
                var newUser = AppUser(id: id, email: email ?? "unknown@email.com", role: defaultRole)
                newUser.aboutMe = ""
                newUser.education = []
                newUser.expertise = []
                try await db.collection(self.usersCollection).document(id).setData(from: newUser)
                print("FetchUserData: Saved new default user document.")
                self.user = newUser
                self.role = newUser.role
            }
            if !self.isAuthenticated { self.isAuthenticated = true }
        } catch {
            print("!!! FetchUserData FAILED for user \(id): \(error.localizedDescription)")
            self.isLoading = false
            return
        }
        self.isLoading = false
        print("FetchUserData: Loading finished successfully for UID: \(id).")
    }

    // MARK: - State Reset
    @MainActor
    private func resetState() {
        print("AuthManager: Resetting state (signed out or critical error).")
        self.user = nil
        self.isAuthenticated = false
        self.role = .unselected
        self.isLoading = false
        self.isCurrentlySigningUp = false
    }

    // MARK: - Public Actions

    // --- SIGN IN ACTION ---
    func login(email: String, password: String) async throws {
        print("AuthManager: Attempting Sign In for \(email)...")
        if self.isCurrentlySigningUp {
             print("AuthManager Sign In: Resetting isCurrentlySigningUp flag before login.")
             self.isCurrentlySigningUp = false
        }
        self.isLoading = true
        do {
            _ = try await Auth.auth().signIn(withEmail: email, password: password)
            print("AuthManager: Firebase Sign In successful for \(email). Listener will handle data fetch.")
        } catch {
            print("!!! AuthManager Sign In FAILED for \(email): \(error.localizedDescription)")
            resetState()
            throw error
        }
    }

    // --- SIGN UP ACTION ---
    func signUp(
        name: String,
        email: String,
        phone: String,
        password: String,
        role: UserRole,
        drivingSchool: String?,
        address: String?,
        photoData: Data?,
        hourlyRate: Double?
    ) async throws {
        guard !self.isCurrentlySigningUp else {
             print("!!! SignUp attempted while another signup was in progress. Aborting.")
             throw NSError(domain: "AuthManager", code: -10, userInfo: [NSLocalizedDescriptionKey: "Sign up already in progress."])
        }
        self.isCurrentlySigningUp = true
        self.isLoading = true
        print("SignUp: Starting process for \(email)...")
        var uid: String = ""
        var photoURL: String? = nil
        do {
            print("SignUp: Creating Auth user...")
            let result = try await Auth.auth().createUser(withEmail: email, password: password)
            uid = result.user.uid
            print("SignUp: Auth user created with UID: \(uid)")
            if let data = photoData {
                print("SignUp: Photo data found, attempting upload for UID: \(uid)...")
                photoURL = try await StorageManager.shared.uploadProfilePhoto(photoData: data, userID: uid)
                print("SignUp: Photo upload successful. URL: \(photoURL ?? "N/A")")
            } else { print("SignUp: No photo data provided.") }
            var newUser = AppUser(id: uid, email: email, name: name, role: role)
            newUser.phone = phone
            newUser.drivingSchool = drivingSchool
            newUser.address = address
            newUser.photoURL = photoURL
            newUser.hourlyRate = hourlyRate
            newUser.aboutMe = ""
            newUser.education = []
            if role == .instructor { newUser.expertise = [] }
            print("SignUp: Saving user details to Firestore for UID: \(uid)...")
            try await db.collection(usersCollection).document(uid).setData(from: newUser)
            print("SignUp: Firestore save successful.")
            print("SignUp: Process complete. Updating local state manually.")
            self.user = newUser
            self.role = newUser.role
            self.isAuthenticated = true
            self.isLoading = false
            self.isCurrentlySigningUp = false
        } catch {
            print("!!! SignUp FAILED: \(error.localizedDescription)")
            if !uid.isEmpty && Auth.auth().currentUser?.uid == uid {
                print("SignUp: Cleaning up partially created Auth user \(uid)...")
                try? await Auth.auth().currentUser?.delete()
                print("SignUp: Partial Auth user deleted.")
            }
            resetState()
            throw error
        }
    }

    // --- UPDATE PROFILE ACTION ---
    func updateUserProfile(
        name: String,
        phone: String,
        address: String,
        drivingSchool: String?,
        hourlyRate: Double?,
        photoData: Data?,
        aboutMe: String?,
        education: [EducationEntry]?,
        expertise: [String]?
    ) async throws {
        guard let currentUserID = user?.id else {
            throw NSError(domain: "AuthManager", code: 401, userInfo: [NSLocalizedDescriptionKey: "User not logged in."])
        }

        print("UpdateProfile: Starting update for user \(currentUserID)")
        var dataToUpdate: [String: Any] = [:]
        var uploadedPhotoURL: String? = nil

        if let data = photoData {
            print("UpdateProfile: New photo data found, attempting upload...")
            do {
                uploadedPhotoURL = try await StorageManager.shared.uploadProfilePhoto(photoData: data, userID: currentUserID)
                dataToUpdate["photoURL"] = uploadedPhotoURL
                print("UpdateProfile: Photo uploaded successfully. URL: \(uploadedPhotoURL ?? "N/A")")
            } catch {
                print("!!! UpdateProfile Photo Upload FAILED: \(error.localizedDescription)")
                throw error
            }
        } else {
            print("UpdateProfile: No new photo data provided.")
        }

        if name != self.user?.name { dataToUpdate["name"] = name }
        if phone != self.user?.phone { dataToUpdate["phone"] = phone }
        if address != self.user?.address { dataToUpdate["address"] = address }
        if aboutMe != self.user?.aboutMe { dataToUpdate["aboutMe"] = aboutMe ?? "" }

        let currentEducation = self.user?.education ?? []
        let newEducation = education ?? []
        var educationChanged = false
        if currentEducation.count != newEducation.count {
            educationChanged = true
        } else {
            for i in 0..<currentEducation.count {
                if currentEducation[i].title != newEducation[i].title ||
                   currentEducation[i].subtitle != newEducation[i].subtitle ||
                   currentEducation[i].years != newEducation[i].years {
                    educationChanged = true
                    break
                }
            }
        }

        if educationChanged {
             let eduDicts = newEducation.map {
                 ["id": $0.id.uuidString, "title": $0.title, "subtitle": $0.subtitle, "years": $0.years]
             }
             dataToUpdate["education"] = eduDicts
             print("UpdateProfile: Education data changed, adding to update.")
        } else {
             print("UpdateProfile: Education data unchanged.")
        }

        if role == .instructor {
            if drivingSchool != self.user?.drivingSchool { dataToUpdate["drivingSchool"] = drivingSchool ?? "" }
            let rateDouble = Double(hourlyRate ?? 0.0)
            if rateDouble != self.user?.hourlyRate { dataToUpdate["hourlyRate"] = rateDouble }

            let currentExpertise = self.user?.expertise ?? []
            let newExpertise = expertise ?? []
            if currentExpertise.count != newExpertise.count || Set(currentExpertise) != Set(newExpertise) {
                 dataToUpdate["expertise"] = newExpertise
                 print("UpdateProfile: Expertise data changed, adding to update.")
            } else {
                 print("UpdateProfile: Expertise data unchanged.")
            }
        }

        if !dataToUpdate.isEmpty {
            print("UpdateProfile: Updating Firestore with fields: \(dataToUpdate.keys)")
            do {
                try await db.collection(usersCollection).document(currentUserID).updateData(dataToUpdate)
                print("UpdateProfile: Firestore update successful.")
            } catch {
                print("!!! UpdateProfile Firestore Update FAILED: \(error.localizedDescription)")
                throw error
            }

            if dataToUpdate["name"] != nil { self.user?.name = name }
            if dataToUpdate["phone"] != nil { self.user?.phone = phone }
            if dataToUpdate["address"] != nil { self.user?.address = address }
            if dataToUpdate["aboutMe"] != nil { self.user?.aboutMe = aboutMe }
            if dataToUpdate["education"] != nil { self.user?.education = education }
            if dataToUpdate["photoURL"] != nil { self.user?.photoURL = uploadedPhotoURL }

            if self.role == .instructor {
                if dataToUpdate["drivingSchool"] != nil { self.user?.drivingSchool = drivingSchool }
                if dataToUpdate["hourlyRate"] != nil { self.user?.hourlyRate = Double(hourlyRate ?? 0.0) }
                if dataToUpdate["expertise"] != nil { self.user?.expertise = expertise }
            }

        } else {
            print("UpdateProfile: No data changed, skipping Firestore update.")
        }
        print("UpdateProfile: Update process finished.")
    }

    // --- *** ADD THIS NEW FUNCTION *** ---
    /// Syncs the local AppUser's instructorIDs based on approved requests.
    /// This is called by the student's "MyInstructorsView".
    func syncApprovedInstructors(approvedInstructorIDs: [String]) async {
        guard let currentUserID = self.user?.id else { return }
        
        // Use a Set for easy comparison
        let localIDs = Set(self.user?.instructorIDs ?? [])
        let approvedIDs = Set(approvedInstructorIDs)
        
        // Only write to Firestore if the lists are different
        if localIDs != approvedIDs {
            print("AuthManager: Mismatch found. Syncing student's instructorIDs array...")
            do {
                try await db.collection(usersCollection).document(currentUserID).updateData([
                    "instructorIDs": approvedInstructorIDs // Set the array to the correct, complete list
                ])
                // Update local user object
                self.user?.instructorIDs = approvedInstructorIDs
                print("AuthManager: Student's instructorIDs synced successfully.")
            } catch {
                print("!!! AuthManager: Failed to sync instructorIDs: \(error.localizedDescription)")
            }
        } else {
            print("AuthManager: Student's instructorIDs are already in sync.")
        }
    }
    // --- *** END OF NEW FUNCTION *** ---

    // Sign Out Action
    func logout() throws {
        print("AuthManager: Attempting Sign Out...")
        try Auth.auth().signOut()
        print("AuthManager: Firebase Sign Out successful. Listener will reset state.")
    }

    // Password Reset Action
    func sendPasswordReset(email: String) async throws {
        print("AuthManager: Sending password reset email to \(email)...")
        try await Auth.auth().sendPasswordReset(withEmail: email)
        print("AuthManager: Password reset email sent successfully.")
    }

    // Cleanup listener
    deinit {
        if let handle = authHandle {
            print("AuthManager: Deinitializing and removing AuthStateDidChangeListener.")
            Auth.auth().removeStateDidChangeListener(handle)
        }
    }
}
