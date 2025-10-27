import Combine
import Foundation
import FirebaseAuth
import FirebaseFirestore
import UIKit // Import for UIImage

@MainActor // <-- ADDED: Ensures class runs on the main thread
class AuthManager: ObservableObject {
    @Published var user: AppUser? = nil
    @Published var isAuthenticated: Bool = false
    @Published var isLoading: Bool = true
    @Published var role: UserRole = .unselected

    private var authHandle: AuthStateDidChangeListenerHandle?
    private let db = Firestore.firestore()
    private let usersCollection = "users"
    
    // --- THIS FLAG FIXES THE BUG ---
    private var isSigningUp = false

    init() {
        setupAuthStateListener()
    }

    // Listens to Firebase Auth changes
    private func setupAuthStateListener() {
        isLoading = true
        authHandle = Auth.auth().addStateDidChangeListener { [weak self] auth, firebaseUser in
            // Ensure we're on the main thread for UI updates
            Task { @MainActor in
                guard let self = self else { return }

                if let firebaseUser = firebaseUser {
                    self.isAuthenticated = true
                    // We still call fetchUserData, but it needs to be smarter
                    await self.fetchUserData(id: firebaseUser.uid, email: firebaseUser.email)
                } else {
                    self.resetState()
                }
            }
        }
    }

    // Make this async
    private func fetchUserData(id: String, email: String?) async {
        // If we are in the middle of a signUp, don't do anything.
        // The signUp function is now responsible for setting the user.
        guard !self.isSigningUp else {
            print("FetchUserData: SignUp in progress, deferring.")
            self.isLoading = false
            return
        }
        
        do {
            let document = try await db.collection(usersCollection).document(id).getDocument()
            
            if document.exists, var appUser = try? document.data(as: AppUser.self) {
                // User profile found
                if appUser.role == .unselected {
                    appUser.role = .student
                    try? await self.updateRole(to: .student) // Update in background
                }
                self.user = appUser
                self.role = appUser.role
            } else {
                // No document found, create a new default user
                print("FetchUserData: No document found, creating new default user.")
                let defaultRole: UserRole = .student
                var newUser = AppUser(id: id, email: email ?? "unknown@email.com", role: defaultRole)
                
                try db.collection(self.usersCollection).document(id).setData(from: newUser)
                
                self.user = newUser
                self.role = newUser.role
            }
        } catch {
            print("Error fetching user data: \(error.localizedDescription)")
            // Handle error, maybe reset state
            self.resetState()
        }
        self.isLoading = false
    }
    
    @MainActor
    private func resetState() {
        self.user = nil
        self.isAuthenticated = false
        self.role = .unselected
        self.isLoading = false
    }

    // MARK: - Public Actions

    func login(email: String, password: String) async throws {
        _ = try await Auth.auth().signIn(withEmail: email, password: password)
    }
    
    // --- THIS SIGNUP FUNCTION IS NOW FIXED ---
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
        
        self.isSigningUp = true // <-- SET FLAG
        
        // 1. Create user in Firebase Auth
        let result = try await Auth.auth().createUser(withEmail: email, password: password)
        let uid = result.user.uid
        
        // 2. TODO: Upload Photo to Firebase Storage
        // This is why your image isn't saving. This task is not implemented.
        // You would need to use FirebaseStorage.storage().reference().putData(photoData)
        // and get a downloadURL here.
        let photoURL: String? = nil // Placeholder
        
        // 3. Save detailed profile to Firestore
        var newUser = AppUser(id: uid, email: email, name: name, role: role)
        newUser.phone = phone
        newUser.drivingSchool = drivingSchool
        newUser.address = address
        newUser.photoURL = photoURL // This is nil, so no image is saved
        newUser.hourlyRate = hourlyRate
        
        try await db.collection(usersCollection).document(uid).setData(from: newUser)
        
        // 4. Manually update local state (This completes the fix)
        // Since the class is @MainActor, these updates are safe
        print("SignUp: Successfully created user and setting local state.")
        self.user = newUser
        self.role = newUser.role
        self.isAuthenticated = true // This will trigger RootView update
        self.isLoading = false
        self.isSigningUp = false // <-- UNSET FLAG
    }
    
    // --- THIS UPDATE FUNCTION IS ALSO CORRECTED ---
    func updateUserProfile(
        name: String,
        phone: String,
        address: String,
        drivingSchool: String?,
        hourlyRate: Double?,
        photoData: Data?
    ) async throws {
        guard let currentUserID = user?.id else {
            throw NSError(domain: "AuthManager", code: 401, userInfo: [NSLocalizedDescriptionKey: "User not logged in."])
        }
        
        // 1. TODO: Upload Photo
        let photoURL: String? = nil
        
        // 2. Prepare data
        var dataToUpdate: [String: Any] = [
            "name": name,
            "phone": phone,
            "address": address
        ]
        
        if role == .instructor {
            dataToUpdate["drivingSchool"] = drivingSchool ?? ""
            dataToUpdate["hourlyRate"] = hourlyRate ?? 0.0
        }
        
        if let photoURL = photoURL {
            dataToUpdate["photoURL"] = photoURL
        }
        
        // 3. Update Firestore
        try await db.collection(usersCollection).document(currentUserID).updateData(dataToUpdate)
        
        // 4. Update local user object
        // Class is @MainActor, so this is safe
        self.user?.name = name
        self.user?.phone = phone
        self.user?.address = address
        if self.role == .instructor {
            self.user?.drivingSchool = drivingSchool
            self.user?.hourlyRate = hourlyRate
        }
        if let photoURL = photoURL {
            self.user?.photoURL = photoURL
        }
    }
    
    @MainActor
    func updateRole(to newRole: UserRole) async throws {
        guard let currentUserID = user?.id else { throw NSError(domain: "AuthManager", code: 401, userInfo: [NSLocalizedDescriptionKey: "User not logged in."]) }
        
        try await db.collection(usersCollection).document(currentUserID).updateData(["role": newRole.rawValue])
        
        self.user?.role = newRole
        self.role = newRole
    }

    func logout() throws {
        try Auth.auth().signOut()
    }
    
    func sendPasswordReset(email: String) async throws {
        try await Auth.auth().sendPasswordReset(withEmail: email)
    }

    deinit {
        if let handle = authHandle {
            Auth.auth().removeStateDidChangeListener(handle)
        }
    }
}
