// File: arafatrahman/myinstructor/MyInstructor-main/MyInstructor/Features/Community/InstructorPublicProfileView.swift
// --- UPDATED: handleFollowTap now updates AuthManager to sync follow state with Community Hub ---

import SwiftUI
import FirebaseFirestore

enum RequestButtonState {
    case idle
    case pending
    case approved
    case denied
    case blocked // Blocked by INSTRUCTOR
    case blockedByStudent // Blocked by STUDENT
    case completed
}

struct InstructorPublicProfileView: View {
    @EnvironmentObject var authManager: AuthManager
    @EnvironmentObject var communityManager: CommunityManager
    
    let instructorID: String
    
    @State private var instructor: AppUser?
    @State private var isLoading = true
    
    @State private var requestState: RequestButtonState = .idle
    @State private var currentRequestID: String? = nil
    @State private var showSuccessAlert = false
    @State private var alertMessage: String? = nil
    
    // Social State
    @State private var isFollowing = false
    
    private var appBlue: Color { return Color.primaryBlue }
    private var isMe: Bool { authManager.user?.id == instructorID }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                if let user = instructor {
                    ProfileHeaderCard(
                        user: user,
                        isStudent: authManager.role == .student,
                        isInstructor: user.role == .instructor,
                        requestState: requestState,
                        isFollowing: isFollowing,
                        isMe: isMe,
                        onActionTap: handleRequestButtonTap,
                        onFollowTap: handleFollowTap
                    )
                    .padding(.horizontal)
                    .padding(.top, 16)
                    
                    // Pass isMe to handle Email privacy
                    ContactCard(user: user, isMe: isMe).padding(.horizontal)
                    
                    if user.role == .instructor { RateHighlightCard(user: user).padding(.horizontal) }
                    EducationCard(education: user.education).padding(.horizontal)
                    AboutCard(aboutText: user.aboutMe).padding(.horizontal)
                    if user.role == .instructor { ExpertiseCard(skills: user.expertise).padding(.horizontal) }
                    
                    if let alertMessage, !showSuccessAlert {
                        Text(alertMessage).font(.caption).foregroundColor(.warningRed).multilineTextAlignment(.center).padding()
                    }
                } else if isLoading {
                    ProgressView().padding(.top, 50)
                } else {
                    Text("Could not load profile.").padding()
                }
            }
            .padding(.bottom, 20)
        }
        .navigationTitle(instructor?.name ?? "Profile")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if !isMe {
                ToolbarItem(placement: .navigationBarTrailing) {
                    HStack(spacing: 16) {
                        if requestState == .approved, let instructorAppUser = instructor {
                            NavigationLink(destination: ChatLoadingView(otherUser: instructorAppUser)) {
                                Image(systemName: "message.circle.fill").font(.title3).foregroundColor(appBlue)
                            }
                        }
                        Menu {
                            Button(role: .destructive) {
                                Task { await blockUser() }
                            } label: {
                                Label("Block User", systemImage: "hand.raised.fill")
                            }
                        } label: {
                            Image(systemName: "ellipsis.circle").font(.title3).foregroundColor(.textLight)
                        }
                    }
                }
            }
        }
        .background(Color(.systemBackground))
        .task { await loadData() }
        .alert("Success", isPresented: $showSuccessAlert, presenting: alertMessage) { message in
            Button("OK") { }
        } message: { message in Text(message) }
    }
    
    // MARK: - Logic
    
    func handleRequestButtonTap() {
        Task {
            isLoading = true
            alertMessage = nil
            switch requestState {
            case .idle, .denied, .completed: await sendRequest()
            case .pending: await cancelRequest()
            default: break
            }
            isLoading = false
        }
    }
    
    func handleFollowTap() {
        Task {
            guard let currentID = authManager.user?.id, let name = authManager.user?.name else { return }
            do {
                if isFollowing {
                    // --- UNFOLLOW ---
                    try await communityManager.unfollowUser(currentUserID: currentID, targetUserID: instructorID)
                    isFollowing = false
                    
                    // 1. Update Local Instructor Object (for UI count on this screen)
                    if var followers = instructor?.followers {
                        if let index = followers.firstIndex(of: currentID) { followers.remove(at: index) }
                        instructor?.followers = followers
                    }
                    
                    // 2. Update AuthManager (so Community Hub & Feed knows instantly)
                    if var myFollowing = authManager.user?.following {
                        if let index = myFollowing.firstIndex(of: instructorID) {
                            myFollowing.remove(at: index)
                            authManager.user?.following = myFollowing
                        }
                    }
                    
                } else {
                    // --- FOLLOW ---
                    try await communityManager.followUser(currentUserID: currentID, targetUserID: instructorID, currentUserName: name)
                    isFollowing = true
                    
                    // 1. Update Local Instructor Object
                    if instructor?.followers == nil { instructor?.followers = [] }
                    instructor?.followers?.append(currentID)
                    
                    // 2. Update AuthManager
                    if authManager.user?.following == nil { authManager.user?.following = [] }
                    if authManager.user?.following?.contains(instructorID) == false {
                        authManager.user?.following?.append(instructorID)
                    }
                }
            } catch { print("Follow error: \(error)") }
        }
    }
    
    func blockUser() async {
        guard let currentID = authManager.user?.id else { return }
        do {
            try await communityManager.blockUserGeneric(blockerID: currentID, targetID: instructorID)
            alertMessage = "User blocked."
            showSuccessAlert = true
            if authManager.role == .student {
                if let user = authManager.user {
                    try await communityManager.blockInstructor(instructorID: instructorID, student: user)
                }
            }
            await loadData()
        } catch { alertMessage = "Error blocking: \(error.localizedDescription)" }
    }
    
    func loadData() async {
        isLoading = true
        guard let myID = authManager.user?.id else { return }
        do {
            let doc = try await Firestore.firestore().collection("users").document(instructorID).getDocument()
            self.instructor = try doc.data(as: AppUser.self)
            
            if let followers = self.instructor?.followers {
                self.isFollowing = followers.contains(myID)
            }
            
            if authManager.role == .student {
                let requests = try await communityManager.fetchSentRequests(for: myID)
                if let existing = requests.first(where: { $0.instructorID == instructorID }) {
                    self.currentRequestID = existing.id
                    switch existing.status {
                    case .pending: self.requestState = .pending
                    case .approved: self.requestState = .approved
                    case .denied: self.requestState = .denied
                    case .completed: self.requestState = .completed
                    case .blocked: self.requestState = (existing.blockedBy == "student") ? .blockedByStudent : .blocked
                    }
                } else {
                    self.requestState = .idle
                    self.currentRequestID = nil
                }
            }
        } catch { print("Error: \(error)") }
        isLoading = false
    }
    
    func sendRequest() async {
        guard let currentUser = authManager.user else { return }
        do {
            try await communityManager.sendRequest(from: currentUser, to: instructorID)
            alertMessage = "Request sent!"; showSuccessAlert = true; await loadData()
        } catch { alertMessage = error.localizedDescription }
    }
    
    func cancelRequest() async {
        guard let id = currentRequestID else { return }
        try? await communityManager.cancelRequest(requestID: id)
        alertMessage = "Request cancelled."; showSuccessAlert = true; await loadData()
    }
}

// MARK: - Subviews

private struct ProfileHeaderCard: View {
    let user: AppUser
    let isStudent: Bool
    let isInstructor: Bool
    let requestState: RequestButtonState
    let isFollowing: Bool
    let isMe: Bool
    let onActionTap: () -> Void
    let onFollowTap: () -> Void
    
    private var profileImageURL: URL? {
        guard let urlString = user.photoURL, !urlString.isEmpty else { return nil }
        return URL(string: urlString)
    }
    private var locationString: String {
        if let address = user.address, !address.isEmpty {
            return address.components(separatedBy: ",").first?.trimmingCharacters(in: .whitespaces) ?? "Location N/A"
        }
        return "Location N/A"
    }
    
    private var followersCount: Int { user.followers?.count ?? 0 }
    private var followingCount: Int { user.following?.count ?? 0 }
    
    // --- CHECK: Should stats be visible? ---
    // Visible if: It's MY profile OR the user hasn't hidden them.
    private var showStats: Bool {
        return isMe || !(user.hideFollowers ?? false)
    }
    
    var buttonConfig: (text: String, color: Color, isDisabled: Bool) {
        switch requestState {
        case .idle: return ("Become a Student", .primaryBlue, false)
        case .pending: return ("Request Pending", .gray, false)
        case .approved: return ("Approved Student", .accentGreen, true)
        case .denied: return ("Request Denied", .orange, false)
        case .blocked: return ("Blocked by Instructor", .red, true)
        case .blockedByStudent: return ("Blocked", .gray, true)
        case .completed: return ("Reconnect", .primaryBlue, false)
        }
    }
    
    var body: some View {
        VStack(spacing: 12) {
            AsyncImage(url: profileImageURL) { phase in
                if let image = phase.image { image.resizable().scaledToFill() }
                else { Image(systemName: "person.crop.circle.fill").resizable().foregroundColor(.secondary) }
            }
            .frame(width: 100, height: 100)
            .background(Color(.systemGray5)).clipShape(Circle())
            .overlay(Circle().stroke(Color.primaryBlue, lineWidth: 3))
            .padding(.top, 20)
            
            Text(user.name ?? "User Name").font(.system(size: 22, weight: .semibold)).foregroundColor(.primary)
            Text(user.role.rawValue.capitalized).font(.system(size: 15)).foregroundColor(.secondary)
            HStack(spacing: 4) {
                Image(systemName: "mappin.and.ellipse")
                Text(locationString)
            }.font(.system(size: 14)).foregroundColor(Color.primaryBlue)
            
            // --- UPDATED STATS DISPLAY ---
            if showStats {
                HStack(spacing: 40) {
                    VStack(spacing: 2) {
                        Text("\(followersCount)")
                            .font(.headline).bold()
                            .foregroundColor(.primary)
                        Text("Followers")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    VStack(spacing: 2) {
                        Text("\(followingCount)")
                            .font(.headline).bold()
                            .foregroundColor(.primary)
                        Text("Following")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.vertical, 8)
            }
            // -----------------------------
            
            if !isMe {
                HStack(spacing: 12) {
                    Button(action: onFollowTap) {
                        Text(isFollowing ? "Unfollow" : "Follow")
                            .font(.headline).bold()
                            .padding(.vertical, 10)
                            .padding(.horizontal, 24)
                            .background(isFollowing ? Color.gray.opacity(0.2) : Color.primaryBlue)
                            .foregroundColor(isFollowing ? .primary : .white)
                            .cornerRadius(20)
                    }
                    
                    if isStudent && isInstructor {
                        Button(action: onActionTap) {
                            Text(buttonConfig.text)
                                .font(.headline).bold()
                                .padding(.vertical, 10)
                                .padding(.horizontal, 24)
                                .background(buttonConfig.color)
                                .foregroundColor(.white)
                                .cornerRadius(20)
                        }
                        .disabled(buttonConfig.isDisabled)
                    }
                }
                .padding(.top, 8)
            }
            
            Spacer().frame(height: 12)
        }
        .frame(maxWidth: .infinity).background(Color(.systemBackground)).cornerRadius(16).shadow(color: Color.black.opacity(0.08), radius: 4, y: 2)
    }
}

private struct ContactCard: View {
    let user: AppUser
    let isMe: Bool // passed from parent
    
    // Check if email should be shown
    private var showEmail: Bool {
        return isMe || !(user.hideEmail ?? false)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("CONTACT").font(.system(size: 13, weight: .bold)).foregroundColor(.secondary).padding(.horizontal, 16).padding(.top, 12).padding(.bottom, 8)
            Divider().padding(.horizontal, 16)
            
            // Conditionally show email row
            if showEmail {
                ContactRow(icon: "envelope.fill", label: "Email", value: user.email)
            } else {
                // Optional: Show "Hidden" or skip entirely. Skipping looks cleaner.
                // ContactRow(icon: "envelope.fill", label: "Email", value: "Hidden")
            }
            
            ContactRow(icon: "phone.fill", label: "Phone", value: user.phone ?? "Not provided")
            ContactRow(icon: "mappin.and.ellipse", label: "Address", value: user.address ?? "Not provided")
        }.background(Color(.systemBackground)).cornerRadius(16).shadow(color: Color.black.opacity(0.08), radius: 4, y: 2)
    }
}

// ... (Other cards remain unchanged: RateHighlightCard, EducationCard, EduRow, AboutCard, ExpertiseCard)
private struct RateHighlightCard: View {
    let user: AppUser
    var body: some View {
        VStack(spacing: 4) {
            Text("Hourly Rate").font(.system(size: 15)).foregroundColor(.white.opacity(0.9))
            Text(user.hourlyRate ?? 0.0, format: .currency(code: "GBP")).font(.system(size: 36, weight: .bold)).foregroundColor(.white)
            Text("per hour").font(.system(size: 15)).foregroundColor(.white.opacity(0.9))
        }.padding(20).frame(maxWidth: .infinity).background(LinearGradient(gradient: Gradient(colors: [Color.primaryBlue, Color(red: 0.35, green: 0.34, blue: 0.84)]), startPoint: .topLeading, endPoint: .bottomTrailing)).cornerRadius(16).shadow(color: Color.primaryBlue.opacity(0.4), radius: 8, y: 4)
    }
}

private struct EducationCard: View {
    let education: [EducationEntry]?
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("EDUCATION OR CERTIFICATION").font(.system(size: 13, weight: .bold)).foregroundColor(.secondary).padding(.horizontal, 16).padding(.top, 12).padding(.bottom, 8)
            Divider().padding(.horizontal, 16)
            if let education = education, !education.isEmpty {
                VStack(alignment: .leading, spacing: 14) {
                    ForEach(education) { entry in
                        EduRow(title: entry.title, subtitle: entry.subtitle, years: entry.years)
                        if entry.id != education.last?.id { Divider().padding(.horizontal, 16) }
                    }
                }.padding(.vertical, 14)
            } else { Text("No education or certifications added.").font(.system(size: 15)).foregroundColor(.secondary).padding(16) }
        }.background(Color(.systemBackground)).cornerRadius(16).shadow(color: Color.black.opacity(0.08), radius: 4, y: 2)
    }
}

private struct EduRow: View {
    let title: String; let subtitle: String; let years: String
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(.system(size: 17, weight: .semibold)).foregroundColor(.primary)
            Text(subtitle).font(.system(size: 15)).foregroundColor(Color.primaryBlue)
            Text(years).font(.system(size: 13)).foregroundColor(.secondary)
        }.padding(.horizontal, 16)
    }
}

private struct AboutCard: View {
    let aboutText: String?
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("ABOUT").font(.system(size: 13, weight: .bold)).foregroundColor(.secondary).padding(.horizontal, 16).padding(.top, 12).padding(.bottom, 8)
            Divider().padding(.horizontal, 16)
            if let text = aboutText, !text.isEmpty {
                Text(text).font(.system(size: 16)).foregroundColor(.primary).lineSpacing(4).padding(.horizontal, 16).padding(.vertical, 16)
            } else { Text("No bio added.").font(.system(size: 15)).foregroundColor(.secondary).padding(16) }
        }.background(Color(.systemBackground)).cornerRadius(16).shadow(color: Color.black.opacity(0.08), radius: 4, y: 2)
    }
}

private struct ExpertiseCard: View {
    let skills: [String]?
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("EXPERTISE").font(.system(size: 13, weight: .bold)).foregroundColor(.secondary).padding(.horizontal, 16).padding(.top, 12).padding(.bottom, 8)
            Divider().padding(.horizontal, 16)
            if let skills = skills, !skills.isEmpty {
                FlowLayout(alignment: .leading, spacing: 8) {
                    ForEach(skills, id: \.self) { skill in
                        Text(skill).font(.system(size: 14, weight: .medium)).padding(.horizontal, 12).padding(.vertical, 6).background(Color(.systemGray5)).cornerRadius(12).foregroundColor(.primary)
                    }
                }.padding(.horizontal, 16).padding(.vertical, 16)
            } else { Text("No skills added.").font(.system(size: 15)).foregroundColor(.secondary).padding(16) }
        }.background(Color(.systemBackground)).cornerRadius(16).shadow(color: Color.black.opacity(0.08), radius: 4, y: 2)
    }
}
