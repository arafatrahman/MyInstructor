// File: arafatrahman/myinstructor/MyInstructor-main/MyInstructor/Core/Managers/AuthManager.swift
// --- UPDATED: Added 'updatePrivacySettings' and 'deleteAccount' ---

import Combine
import Foundation
import FirebaseAuth
import FirebaseFirestore
import FirebaseStorage
import UIKit

@MainActor
class AuthManager: ObservableObject {
    // MARK: - Published Properties
    @Published var user: AppUser? = nil
    @Published var isAuthenticated: Bool = false
    @Published var isLoading: Bool = true
    @Published var role: UserRole = .unselected

    // MARK: - Private Properties
    private var authHandle: AuthStateDidChangeListenerHandle?
    private let db = Firestore.firestore()
    private let usersCollection = "users"

    private var isCurrentlySigningUp = false

    // MARK: - Initialization
    init() {
        self.isLoading = true
        setupAuthStateListener()
    }

    // MARK: - Auth State Listener
    private func setupAuthStateListener() {
        authHandle = Auth.auth().addStateDidChangeListener { [weak self] auth, firebaseUser in
            Task { @MainActor in
                guard let self = self else { return }
                if let firebaseUser = firebaseUser {
                    if !self.isCurrentlySigningUp {
                        if !self.isAuthenticated { self.isAuthenticated = true }
                        await self.fetchUserData(id: firebaseUser.uid, email: firebaseUser.email)
                    }
                } else {
                    self.resetState()
                }
            }
        }
    }

    // MARK: - Data Fetching
    private func fetchUserData(id: String, email: String?) async {
        guard !self.isCurrentlySigningUp else { return }
        if !self.isLoading { self.isLoading = true }

        do {
            let document = try await db.collection(usersCollection).document(id).getDocument()
            if document.exists, let appUser = try? document.data(as: AppUser.self) {
                self.user = appUser
                self.role = appUser.role
            } else {
                // Create default user if doc missing
                let defaultRole: UserRole = .student
                var newUser = AppUser(id: id, email: email ?? "unknown@email.com", role: defaultRole)
                newUser.aboutMe = ""
                newUser.education = []
                newUser.expertise = []
                try await db.collection(self.usersCollection).document(id).setData(from: newUser)
                self.user = newUser
                self.role = newUser.role
            }
            if !self.isAuthenticated { self.isAuthenticated = true }
        } catch {
            print("FetchUserData FAILED: \(error.localizedDescription)")
            self.isLoading = false
            return
        }
        self.isLoading = false
    }

    @MainActor
    private func resetState() {
        self.user = nil
        self.isAuthenticated = false
        self.role = .unselected
        self.isLoading = false
        self.isCurrentlySigningUp = false
    }

    // MARK: - Public Actions

    func login(email: String, password: String) async throws {
        if self.isCurrentlySigningUp { self.isCurrentlySigningUp = false }
        self.isLoading = true
        do {
            _ = try await Auth.auth().signIn(withEmail: email, password: password)
        } catch {
            self.isLoading = false
            throw error
        }
    }

    func signUp(name: String, email: String, phone: String, password: String, role: UserRole, drivingSchool: String?, address: String?, photoData: Data?, hourlyRate: Double?) async throws {
        guard !self.isCurrentlySigningUp else { return }
        self.isCurrentlySigningUp = true
        self.isLoading = true
        
        var uid: String = ""
        var photoURL: String? = nil
        do {
            let result = try await Auth.auth().createUser(withEmail: email, password: password)
            uid = result.user.uid
            
            if let data = photoData {
                photoURL = try await StorageManager.shared.uploadProfilePhoto(photoData: data, userID: uid)
            }
            
            var newUser = AppUser(id: uid, email: email, name: name, role: role)
            newUser.phone = phone
            newUser.drivingSchool = drivingSchool
            newUser.address = address
            newUser.photoURL = photoURL
            newUser.hourlyRate = hourlyRate
            newUser.aboutMe = ""
            newUser.education = []
            if role == .instructor { newUser.expertise = [] }
            
            try await db.collection(usersCollection).document(uid).setData(from: newUser)
            
            self.user = newUser
            self.role = newUser.role
            self.isAuthenticated = true
            self.isLoading = false
            self.isCurrentlySigningUp = false
        } catch {
            if !uid.isEmpty && Auth.auth().currentUser?.uid == uid {
                try? await Auth.auth().currentUser?.delete()
            }
            self.isLoading = false
            self.isCurrentlySigningUp = false
            throw error
        }
    }

    func updateUserProfile(name: String, phone: String, address: String, drivingSchool: String?, hourlyRate: Double?, photoData: Data?, aboutMe: String?, education: [EducationEntry]?, expertise: [String]?) async throws {
        guard let currentUserID = user?.id else { return }

        var dataToUpdate: [String: Any] = [:]
        var uploadedPhotoURL: String? = nil

        if let data = photoData {
            uploadedPhotoURL = try await StorageManager.shared.uploadProfilePhoto(photoData: data, userID: currentUserID)
            dataToUpdate["photoURL"] = uploadedPhotoURL
        }

        if name != self.user?.name { dataToUpdate["name"] = name }
        if phone != self.user?.phone { dataToUpdate["phone"] = phone }
        if address != self.user?.address { dataToUpdate["address"] = address }
        if aboutMe != self.user?.aboutMe { dataToUpdate["aboutMe"] = aboutMe ?? "" }
        
        // Complex object handling simplified for brevity - assumes always update if passed
        if let education = education {
             let eduDicts = education.map { ["id": $0.id.uuidString, "title": $0.title, "subtitle": $0.subtitle, "years": $0.years] }
             dataToUpdate["education"] = eduDicts
        }

        if role == .instructor {
            if drivingSchool != self.user?.drivingSchool { dataToUpdate["drivingSchool"] = drivingSchool ?? "" }
            if let rate = hourlyRate { dataToUpdate["hourlyRate"] = rate }
            if let expertise = expertise { dataToUpdate["expertise"] = expertise }
        }

        if !dataToUpdate.isEmpty {
            try await db.collection(usersCollection).document(currentUserID).updateData(dataToUpdate)
            
            // Local update
            if let name = dataToUpdate["name"] as? String { self.user?.name = name }
            if let phone = dataToUpdate["phone"] as? String { self.user?.phone = phone }
            if let url = uploadedPhotoURL { self.user?.photoURL = url }
            if let school = dataToUpdate["drivingSchool"] as? String { self.user?.drivingSchool = school }
            if let rate = dataToUpdate["hourlyRate"] as? Double { self.user?.hourlyRate = rate }
            if let about = dataToUpdate["aboutMe"] as? String { self.user?.aboutMe = about }
            self.user?.education = education
            self.user?.expertise = expertise
        }
    }
    
    // --- NEW: Update Privacy Settings ---
    func updatePrivacySettings(isPrivate: Bool, hideFollowers: Bool, hideEmail: Bool) async throws {
        guard let uid = user?.id else { return }
        
        let data: [String: Any] = [
            "isPrivate": isPrivate,
            "hideFollowers": hideFollowers,
            "hideEmail": hideEmail
        ]
        
        try await db.collection(usersCollection).document(uid).updateData(data)
        
        // Update local state
        self.user?.isPrivate = isPrivate
        self.user?.hideFollowers = hideFollowers
        self.user?.hideEmail = hideEmail
    }
    
    func syncApprovedInstructors(approvedInstructorIDs: [String]) async {
        guard let currentUserID = self.user?.id else { return }
        let localIDs = Set(self.user?.instructorIDs ?? [])
        let approvedIDs = Set(approvedInstructorIDs)
        
        if localIDs != approvedIDs {
            try? await db.collection(usersCollection).document(currentUserID).updateData(["instructorIDs": approvedInstructorIDs])
            self.user?.instructorIDs = approvedInstructorIDs
        }
    }

    func logout() throws {
        try Auth.auth().signOut()
    }
    
    // --- NEW: Delete Account ---
    func deleteAccount() async throws {
        guard let user = Auth.auth().currentUser else { return }
        guard let uid = self.user?.id else { return }
        
        // 1. Delete Firestore User Document
        try await db.collection(usersCollection).document(uid).delete()
        
        // 2. Delete Authentication Account
        // Note: This requires recent login. Re-authentication might be needed in a real app flow.
        try await user.delete()
        
        // 3. Reset Local State
        resetState()
    }

    func sendPasswordReset(email: String) async throws {
        try await Auth.auth().sendPasswordReset(withEmail: email)
    }

    deinit {
        if let handle = authHandle { Auth.auth().removeStateDidChangeListener(handle) }
    }
}
