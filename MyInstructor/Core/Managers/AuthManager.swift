// File: arafatrahman/myinstructor/MyInstructor-main/MyInstructor/Core/Managers/AuthManager.swift
// --- UPDATED: 'deleteAccount' includes Re-auth & Community Post Cleanup ---

import Combine
import Foundation
import FirebaseAuth
import FirebaseFirestore
import FirebaseStorage
import UIKit

@MainActor
class AuthManager: ObservableObject {
    @Published var user: AppUser? = nil
    @Published var isAuthenticated: Bool = false
    @Published var isLoading: Bool = true
    @Published var role: UserRole = .unselected

    private var authHandle: AuthStateDidChangeListenerHandle?
    private let db = Firestore.firestore()
    private let usersCollection = "users"
    private var isCurrentlySigningUp = false

    init() {
        self.isLoading = true
        setupAuthStateListener()
    }

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

    private func fetchUserData(id: String, email: String?) async {
        guard !self.isCurrentlySigningUp else { return }
        if !self.isLoading { self.isLoading = true }

        do {
            let document = try await db.collection(usersCollection).document(id).getDocument()
            if document.exists, var appUser = try? document.data(as: AppUser.self) {
                self.user = appUser
                self.role = appUser.role
            } else {
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
            print("!!! FetchUserData FAILED: \(error.localizedDescription)")
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

    func login(email: String, password: String) async throws {
        if self.isCurrentlySigningUp { self.isCurrentlySigningUp = false }
        self.isLoading = true
        do {
            _ = try await Auth.auth().signIn(withEmail: email, password: password)
        } catch {
            print("Login failed: \(error.localizedDescription)")
            resetState()
            throw error
        }
    }

    func signUp(name: String, email: String, phone: String, password: String, role: UserRole, drivingSchool: String?, address: String?, photoData: Data?, hourlyRate: Double?) async throws {
        guard !self.isCurrentlySigningUp else {
             throw NSError(domain: "AuthManager", code: -10, userInfo: [NSLocalizedDescriptionKey: "Sign up already in progress."])
        }
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
            resetState()
            throw error
        }
    }

    func updateUserProfile(name: String, phone: String, address: String, drivingSchool: String?, hourlyRate: Double?, photoData: Data?, aboutMe: String?, education: [EducationEntry]?, expertise: [String]?) async throws {
        guard let currentUserID = user?.id else {
            throw NSError(domain: "AuthManager", code: 401, userInfo: [NSLocalizedDescriptionKey: "User not logged in."])
        }
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

        let currentEducation = self.user?.education ?? []
        let newEducation = education ?? []
        var educationChanged = false
        if currentEducation.count != newEducation.count { educationChanged = true }
        else {
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
             let eduDicts = newEducation.map { ["id": $0.id.uuidString, "title": $0.title, "subtitle": $0.subtitle, "years": $0.years] }
             dataToUpdate["education"] = eduDicts
        }

        if role == .instructor {
            if drivingSchool != self.user?.drivingSchool { dataToUpdate["drivingSchool"] = drivingSchool ?? "" }
            let rateDouble = Double(hourlyRate ?? 0.0)
            if rateDouble != self.user?.hourlyRate { dataToUpdate["hourlyRate"] = rateDouble }
            let currentExpertise = self.user?.expertise ?? []
            let newExpertise = expertise ?? []
            if currentExpertise.count != newExpertise.count || Set(currentExpertise) != Set(newExpertise) {
                 dataToUpdate["expertise"] = newExpertise
            }
        }

        if !dataToUpdate.isEmpty {
            try await db.collection(usersCollection).document(currentUserID).updateData(dataToUpdate)
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
        }
    }
    
    func updatePrivacySettings(isPrivate: Bool, hideFollowers: Bool, hideEmail: Bool) async throws {
        guard let uid = user?.id else { return }
        let data: [String: Any] = [
            "isPrivate": isPrivate,
            "hideFollowers": hideFollowers,
            "hideEmail": hideEmail
        ]
        try await db.collection(usersCollection).document(uid).updateData(data)
        self.user?.isPrivate = isPrivate
        self.user?.hideFollowers = hideFollowers
        self.user?.hideEmail = hideEmail
    }

    func syncApprovedInstructors(approvedInstructorIDs: [String]) async {
        guard let currentUserID = self.user?.id else { return }
        let localIDs = Set(self.user?.instructorIDs ?? [])
        let approvedIDs = Set(approvedInstructorIDs)
        if localIDs != approvedIDs {
            try? await db.collection(usersCollection).document(currentUserID).updateData([
                "instructorIDs": approvedInstructorIDs
            ])
            self.user?.instructorIDs = approvedInstructorIDs
        }
    }

    func logout() throws {
        try Auth.auth().signOut()
    }
    
    // --- UPDATED: 'deleteAccount' with One-Step Re-authentication ---
    func deleteAccount(password: String) async throws {
        guard let user = Auth.auth().currentUser else { return }
        guard let uid = self.user?.id, let email = user.email else { return }
        
        print("AuthManager: Starting deletion for \(uid)")
        
        // 1. RE-AUTHENTICATE (Solve "Requires Recent Login")
        let credential = EmailAuthProvider.credential(withEmail: email, password: password)
        try await user.reauthenticate(with: credential)
        print("AuthManager: Re-authentication successful.")
        
        // 2. DELETE COMMUNITY POSTS
        await deleteUserCommunityPosts(uid: uid)
        
        // 3. DELETE USER DOC
        do {
            try await db.collection(usersCollection).document(uid).delete()
            print("AuthManager: Firestore user doc deleted.")
        } catch {
            print("AuthManager Warning: Failed to delete user doc: \(error.localizedDescription)")
        }
        
        // 4. DELETE AUTH ACCOUNT
        try await user.delete()
        print("AuthManager: Auth account deleted.")
        
        await resetState()
    }
    
    // Helper to delete posts
    private func deleteUserCommunityPosts(uid: String) async {
        do {
            let postsSnapshot = try await db.collection("community_posts")
                .whereField("authorID", isEqualTo: uid)
                .getDocuments()
            
            let batch = db.batch()
            for doc in postsSnapshot.documents {
                batch.deleteDocument(doc.reference)
            }
            try await batch.commit()
            print("AuthManager: Deleted \(postsSnapshot.count) community posts.")
        } catch {
            print("AuthManager Error: Failed to delete posts: \(error.localizedDescription)")
        }
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
