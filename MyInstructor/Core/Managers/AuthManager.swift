import Combine
import Foundation
import FirebaseAuth
import FirebaseFirestore

class AuthManager: ObservableObject {
    @Published var user: AppUser? = nil
    @Published var isAuthenticated: Bool = false
    @Published var isLoading: Bool = true
    @Published var role: UserRole = .unselected

    private var authHandle: AuthStateDidChangeListenerHandle?
    private let db = Firestore.firestore()
    private let usersCollection = "users"

    init() {
        setupAuthStateListener()
    }

    // Listens to Firebase Auth changes
    private func setupAuthStateListener() {
        isLoading = true
        authHandle = Auth.auth().addStateDidChangeListener { [weak self] auth, firebaseUser in
            guard let self = self else { return }

            if let firebaseUser = firebaseUser {
                self.isAuthenticated = true
                self.fetchUserData(id: firebaseUser.uid, email: firebaseUser.email)
            } else {
                self.resetState()
            }
        }
    }

    // Fetches the detailed AppUser data from Firestore
    private func fetchUserData(id: String, email: String?) {
        db.collection(usersCollection).document(id).getDocument { [weak self] (document, error) in
            guard let self = self else { return }

            if let document = document, document.exists, let appUser = try? document.data(as: AppUser.self) {
                // User profile found
                self.user = appUser
                self.role = appUser.role
            } else {
                // New user: Create a basic profile in Firestore
                let newUser = AppUser(id: id, email: email ?? "unknown@email.com")
                self.user = newUser
                self.role = newUser.role
                
                do {
                    // Save the basic user profile
                    try self.db.collection(self.usersCollection).document(id).setData(from: newUser)
                } catch {
                    print("Error creating new user document: \(error.localizedDescription)")
                }
            }
            self.isLoading = false
        }
    }
    
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
    
    func signUp(name: String, email: String, phone: String, password: String, role: UserRole, drivingSchool: String?) async throws {
        // 1. Create user in Firebase Auth
        let result = try await Auth.auth().createUser(withEmail: email, password: password)
        let uid = result.user.uid
        
        // 2. Save detailed profile to Firestore
        var newUser = AppUser(id: uid, email: email, name: name, role: role)
        newUser.phone = phone
        newUser.drivingSchool = drivingSchool
        
        try db.collection(usersCollection).document(uid).setData(from: newUser)
    }

    func updateRole(to newRole: UserRole) async throws {
        guard let currentUserID = user?.id else { throw NSError(domain: "AuthManager", code: 401, userInfo: [NSLocalizedDescriptionKey: "User not logged in."]) }
        
        // 1. Update Firestore
        try await db.collection(usersCollection).document(currentUserID).updateData(["role": newRole.rawValue])
        
        // 2. Update local state
        self.user?.role = newRole
        self.role = newRole
    }

    func logout() throws {
        try Auth.auth().signOut()
    }

    deinit {
        if let handle = authHandle {
            Auth.auth().removeStateDidChangeListener(handle)
        }
    }
}
