// File: arafatrahman/myinstructor/MyInstructor-main/MyInstructor/Core/Managers/AuthManager.swift
import Combine
import Foundation
import FirebaseAuth
import FirebaseFirestore
import FirebaseStorage // <-- Make sure this is imported
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
        // Start loading immediately and set up the listener
        self.isLoading = true
        print("AuthManager: Initializing and setting up listener.")
        setupAuthStateListener()
    }

    // MARK: - Auth State Listener
    private func setupAuthStateListener() {
        // The listener reacts to ANY auth change (sign in, sign up, sign out)
        authHandle = Auth.auth().addStateDidChangeListener { [weak self] auth, firebaseUser in
            // Ensure updates run on the main thread
            Task { @MainActor in
                guard let self = self else { return }
                print("AuthManager Listener: Auth state changed.")

                if let firebaseUser = firebaseUser {
                    print("AuthManager Listener: User is signed in (UID: \(firebaseUser.uid)). Current isCurrentlySigningUp=\(self.isCurrentlySigningUp)")
                    // User is detected as signed in.
                    // We MUST fetch data unless signUp is *actively* running and will set state itself.
                    if !self.isCurrentlySigningUp {
                        if !self.isAuthenticated { self.isAuthenticated = true } // Update state if needed
                        await self.fetchUserData(id: firebaseUser.uid, email: firebaseUser.email)
                    } else {
                        print("AuthManager Listener: Deferring fetchUserData because signUp is in progress.")
                        // If signUp is running, it MUST set isAuthenticated, user, role, isLoading=false, isCurrentlySigningUp=false itself upon completion.
                    }
                } else {
                    // User is signed out.
                    print("AuthManager Listener: User is signed out.")
                    self.resetState() // Reset everything to signed-out state
                }
            }
        }
    }

    // MARK: - Data Fetching
    // Fetches user data from Firestore, ensuring not to interfere with signUp
    private func fetchUserData(id: String, email: String?) async {
        // Double-check flag, although listener should already prevent this call during signUp
        guard !self.isCurrentlySigningUp else {
            print("FetchUserData: Aborted because signUp is still marked as in progress (this shouldn't normally happen here).")
            return
        }

        print("FetchUserData: Attempting to load user data for UID: \(id)...")
        if !self.isLoading { self.isLoading = true } // Ensure loading state is active

        do {
            let document = try await db.collection(usersCollection).document(id).getDocument()

            if document.exists, var appUser = try? document.data(as: AppUser.self) {
                print("FetchUserData: Document found for user \(id). Role: \(appUser.role)")
                if appUser.role == .unselected {
                    print("FetchUserData: Role unselected, updating to student.")
                    appUser.role = .student
                    // Update role in Firestore without waiting
                    Task.detached { try? await self.updateRole(to: .student) }
                }
                // Update published properties
                self.user = appUser
                self.role = appUser.role
            } else {
                // No document found - This case should primarily be hit by signUp now,
                // but could occur for external logins or corrupted data.
                print("FetchUserData: No document found for \(id). Creating new default user profile.")
                let defaultRole: UserRole = .student
                var newUser = AppUser(id: id, email: email ?? "unknown@email.com", role: defaultRole)
                try await db.collection(self.usersCollection).document(id).setData(from: newUser)
                print("FetchUserData: Saved new default user document.")
                self.user = newUser
                self.role = newUser.role
            }
            // Ensure authentication state reflects reality after data load/creation
            if !self.isAuthenticated { self.isAuthenticated = true }

        } catch {
            print("!!! FetchUserData FAILED for user \(id): \(error.localizedDescription)")
            // If fetching fails, reset fully to signed-out state
            self.resetState()
            return // Stop further execution here
        }

        // Only mark loading complete after successful fetch/creation
        self.isLoading = false
        print("FetchUserData: Loading finished successfully for UID: \(id).")
    }

    // MARK: - State Reset
    // Resets state when user signs out or fetch fails critically
    @MainActor
    private func resetState() {
        print("AuthManager: Resetting state (signed out or critical error).")
        self.user = nil
        self.isAuthenticated = false
        self.role = .unselected
        self.isLoading = false // Ensure loading stops
        self.isCurrentlySigningUp = false // CRITICAL: Reset flag on sign out/error
    }

    // MARK: - Public Actions

    // --- SIGN IN ACTION ---
    func login(email: String, password: String) async throws {
        print("AuthManager: Attempting Sign In for \(email)...")
        // Reset flag just in case, although it should be false unless signUp crashed
        if self.isCurrentlySigningUp {
             print("AuthManager Sign In: Resetting isCurrentlySigningUp flag before login.")
             self.isCurrentlySigningUp = false
        }
        self.isLoading = true // Show loading indicator

        do {
            _ = try await Auth.auth().signIn(withEmail: email, password: password)
            print("AuthManager: Firebase Sign In successful for \(email). Listener will handle data fetch.")
            // SUCCESS: The AuthStateDidChangeListener will now fire.
            // It will see isCurrentlySigningUp is false and proceed to call fetchUserData.
            // fetchUserData will set isLoading = false upon completion.
        } catch {
            print("!!! AuthManager Sign In FAILED for \(email): \(error.localizedDescription)")
            resetState() // Reset state fully on login failure
            throw error // Re-throw error for LoginForm to display
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

        // --- Start Sign Up Process ---
        guard !self.isCurrentlySigningUp else {
             print("!!! SignUp attempted while another signup was in progress. Aborting.")
             throw NSError(domain: "AuthManager", code: -10, userInfo: [NSLocalizedDescriptionKey: "Sign up already in progress."])
        }
        self.isCurrentlySigningUp = true // **** SET FLAG ****
        self.isLoading = true            // Ensure loading indicator is shown
        print("SignUp: Starting process for \(email)...")
        // -----------------------------

        var uid: String = ""
        var photoURL: String? = nil

        do {
            // 1. Create Auth user
            print("SignUp: Creating Auth user...")
            let result = try await Auth.auth().createUser(withEmail: email, password: password)
            uid = result.user.uid
            print("SignUp: Auth user created with UID: \(uid)")

            // 2. Upload Photo (if provided)
            if let data = photoData {
                print("SignUp: Photo data found, attempting upload for UID: \(uid)...")
                photoURL = try await StorageManager.shared.uploadProfilePhoto(photoData: data, userID: uid)
                print("SignUp: Photo upload successful. URL: \(photoURL ?? "N/A")")
            } else {
                print("SignUp: No photo data provided.")
            }

            // 3. Prepare Firestore data
            var newUser = AppUser(id: uid, email: email, name: name, role: role)
            newUser.phone = phone
            newUser.drivingSchool = drivingSchool
            newUser.address = address
            newUser.photoURL = photoURL
            newUser.hourlyRate = hourlyRate
            
            // Set empty defaults for new fields
            newUser.aboutMe = ""
            newUser.education = []
            if role == .instructor {
                newUser.expertise = []
            }

            // 4. Save to Firestore
            print("SignUp: Saving user details to Firestore for UID: \(uid)...")
            try await db.collection(usersCollection).document(uid).setData(from: newUser)
            print("SignUp: Firestore save successful.")

            // --- SUCCESS: Manually update state ---
            print("SignUp: Process complete. Updating local state manually.")
            self.user = newUser
            self.role = newUser.role
            self.isAuthenticated = true // This should trigger UI update via RootView
            self.isLoading = false
            self.isCurrentlySigningUp = false // **** UNSET FLAG ****
            // The listener might fire now or might have fired already, but because isCurrentlySigningUp WAS true, fetchUserData wouldn't have run. Now that the flag is false, subsequent listener events (if any) will work correctly.
            // ------------------------------------

        } catch {
            // --- CATCH BLOCK FOR ANY FAILURE ---
            print("!!! SignUp FAILED: \(error.localizedDescription)")
            // Cleanup: If Auth user was created, delete it
            if !uid.isEmpty && Auth.auth().currentUser?.uid == uid {
                print("SignUp: Cleaning up partially created Auth user \(uid)...")
                try? await Auth.auth().currentUser?.delete()
                print("SignUp: Partial Auth user deleted.")
            }
            // Reset state fully and re-throw error to notify UI
            resetState() // Calls isLoading = false, isCurrentlySigningUp = false, etc.
            throw error // Propagate the error to RegisterForm
        }
    }

    // --- *** THIS IS THE UPDATED FUNCTION *** ---
    // --- UPDATE PROFILE ACTION ---
    func updateUserProfile(
        name: String,
        phone: String,
        address: String,
        drivingSchool: String?,
        hourlyRate: Double?,
        photoData: Data?,
        aboutMe: String?,       // NEW
        education: [EducationEntry]?, // NEW
        expertise: [String]?     // NEW
    ) async throws {
        guard let currentUserID = user?.id else {
            throw NSError(domain: "AuthManager", code: 401, userInfo: [NSLocalizedDescriptionKey: "User not logged in."])
        }

        print("UpdateProfile: Starting update for user \(currentUserID)")
        var dataToUpdate: [String: Any] = [:]
        var uploadedPhotoURL: String? = nil

        // 1. Upload Photo (if provided)
        if let data = photoData {
            print("UpdateProfile: New photo data found, attempting upload...")
            do {
                uploadedPhotoURL = try await StorageManager.shared.uploadProfilePhoto(photoData: data, userID: currentUserID)
                dataToUpdate["photoURL"] = uploadedPhotoURL
                print("UpdateProfile: Photo uploaded successfully. URL: \(uploadedPhotoURL ?? "N/A")")
            } catch {
                print("!!! UpdateProfile Photo Upload FAILED: \(error.localizedDescription)")
                throw error // Stop update if photo upload fails
            }
        } else {
            print("UpdateProfile: No new photo data provided.")
        }

        // 2. Add other fields
        if name != self.user?.name { dataToUpdate["name"] = name }
        if phone != self.user?.phone { dataToUpdate["phone"] = phone }
        if address != self.user?.address { dataToUpdate["address"] = address }
        
        // --- NEW FIELDS LOGIC ---
        if aboutMe != self.user?.aboutMe { dataToUpdate["aboutMe"] = aboutMe ?? "" }
            
        // Convert EducationEntry array to a dictionary array for Firestore
        if let eduData = education {
            let eduDicts = eduData.map {
                ["id": $0.id.uuidString, "school": $0.school, "degree": $0.degree, "years": $0.years]
            }
            // We update the whole array
            dataToUpdate["education"] = eduDicts
        }
        // ------------------------

        if role == .instructor {
            if drivingSchool != self.user?.drivingSchool { dataToUpdate["drivingSchool"] = drivingSchool ?? "" }
            let rateDouble = Double(hourlyRate ?? 0.0)
            if rateDouble != self.user?.hourlyRate { dataToUpdate["hourlyRate"] = rateDouble }
            
            // Expertise is instructor-only
            if let expData = expertise {
                dataToUpdate["expertise"] = expData // Simple array
            }
        }

        // 3. Update Firestore only if there's data to update
        if !dataToUpdate.isEmpty {
            print("UpdateProfile: Updating Firestore with fields: \(dataToUpdate.keys)")
            try await db.collection(usersCollection).document(currentUserID).updateData(dataToUpdate)
            print("UpdateProfile: Firestore update successful.")

            // 4. Update local user object AFTER successful Firestore update
            self.user?.name = name
            self.user?.phone = phone
            self.user?.address = address
            self.user?.aboutMe = aboutMe // NEW
            self.user?.education = education // NEW
            
            if self.role == .instructor {
                self.user?.drivingSchool = drivingSchool
                self.user?.hourlyRate = Double(hourlyRate ?? 0.0)
                self.user?.expertise = expertise // NEW
            }
            // Update photoURL only if it was successfully uploaded AND saved in this call
            if let finalURL = uploadedPhotoURL {
                self.user?.photoURL = finalURL
            }
        } else {
            print("UpdateProfile: No data changed, skipping Firestore update.")
        }
        print("UpdateProfile: Update process finished.")
    }
    // --- *** END OF UPDATED FUNCTION *** ---

    // Updates only the role field
    @MainActor
    func updateRole(to newRole: UserRole) async throws {
        guard let currentUserID = user?.id else { throw NSError(domain: "AuthManager", code: 401, userInfo: [NSLocalizedDescriptionKey: "User not logged in."]) }

        print("UpdateRole: Updating role to \(newRole.rawValue) for UID: \(currentUserID)")
        try await db.collection(usersCollection).document(currentUserID).updateData(["role": newRole.rawValue])
        print("UpdateRole: Firestore role update successful.")

        self.user?.role = newRole
        self.role = newRole
    }

    // Sign Out Action
    func logout() throws {
        print("AuthManager: Attempting Sign Out...")
        try Auth.auth().signOut()
        print("AuthManager: Firebase Sign Out successful. Listener will reset state.")
        // The listener calls resetState() automatically
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
