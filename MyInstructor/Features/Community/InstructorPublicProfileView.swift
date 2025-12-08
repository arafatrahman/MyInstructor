// File: arafatrahman/myinstructor/MyInstructor-main/MyInstructor/Features/Community/InstructorPublicProfileView.swift
// --- UPDATED: Moved Action Button to Main View Body ---

import SwiftUI
import FirebaseFirestore

enum RequestButtonState {
    case idle
    case pending
    case approved
    case denied
    case blocked // Blocked by INSTRUCTOR
    case blockedByStudent // Blocked by STUDENT
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
    
    private var appBlue: Color {
        return Color.primaryBlue
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                if let user = instructor {
                    // --- UPDATED: Passing logic to Header ---
                    ProfileHeaderCard(
                        user: user,
                        isStudent: authManager.role == .student,
                        requestState: requestState,
                        onActionTap: handleRequestButtonTap
                    )
                    .padding(.horizontal)
                    .padding(.top, 16)
                    
                    ContactCard(user: user)
                        .padding(.horizontal)
                    if user.role == .instructor {
                        RateHighlightCard(user: user)
                            .padding(.horizontal)
                    }
                    EducationCard(education: user.education)
                        .padding(.horizontal)
                    AboutCard(aboutText: user.aboutMe)
                        .padding(.horizontal)
                    if user.role == .instructor {
                        ExpertiseCard(skills: user.expertise)
                            .padding(.horizontal)
                    }
                    
                    if let alertMessage, !showSuccessAlert {
                        Text(alertMessage)
                            .font(.caption)
                            .foregroundColor(.warningRed)
                            .multilineTextAlignment(.center)
                            .padding()
                    }
                    
                } else if isLoading {
                    ProgressView()
                        .padding(.top, 50)
                } else {
                    Text("Could not load instructor profile.")
                        .padding()
                }
            }
            .padding(.bottom, 20)
        }
        .navigationTitle(instructor?.name ?? "Profile")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if authManager.role == .student {
                ToolbarItem(placement: .navigationBarTrailing) {
                    HStack(spacing: 16) {
                        // 1. Conditional Message Button (Only if approved)
                        if requestState == .approved, let instructorAppUser = instructor {
                            NavigationLink(destination: ChatLoadingView(otherUser: instructorAppUser)) {
                                Image(systemName: "message.circle.fill")
                                    .font(.title3)
                                    .foregroundColor(appBlue)
                            }
                        }
                        
                        // 2. Block/Unblock Menu (Moved here, main action is now in body)
                        if requestState != .blocked {
                            Menu {
                                if requestState == .blockedByStudent {
                                    Button("Unblock Instructor", role: .destructive) {
                                        Task { await unblockInstructor() }
                                    }
                                } else {
                                    Button("Block Instructor", role: .destructive) {
                                        Task { await blockInstructor() }
                                    }
                                }
                            } label: {
                                Image(systemName: "ellipsis.circle")
                                    .font(.title3)
                                    .foregroundColor(.textLight)
                            }
                        }
                    }
                }
            }
        }
        .background(Color(.systemBackground))
        .task {
            await loadData()
        }
        .alert("Success", isPresented: $showSuccessAlert, presenting: alertMessage) { message in
            Button("OK") { }
        } message: { message in
            Text(message)
        }
    }
    
    // MARK: - Button Logic
    
    func handleRequestButtonTap() {
        Task {
            isLoading = true
            alertMessage = nil
            
            switch requestState {
            case .idle, .denied:
                await sendRequest()
            case .pending:
                await cancelRequest()
            case .approved, .blocked, .blockedByStudent:
                break
            }
            isLoading = false
        }
    }
    
    // MARK: - Data Functions
    
    func loadData() async {
        isLoading = true
        guard let studentID = authManager.user?.id else { return }
        
        do {
            // Fetch the instructor's user object
            let doc = try await Firestore.firestore().collection("users")
                                    .document(instructorID).getDocument()
            self.instructor = try doc.data(as: AppUser.self)
            
            // Check the status of any requests between the student and this instructor
            let requests = try await communityManager.fetchSentRequests(for: studentID)
            
            if let existingRequest = requests.first(where: { $0.instructorID == instructorID }) {
                self.currentRequestID = existingRequest.id
                
                switch existingRequest.status {
                case .pending:
                    self.requestState = .pending
                case .approved:
                    self.requestState = .approved
                case .denied:
                    self.requestState = .denied
                case .blocked:
                    if existingRequest.blockedBy == "student" {
                        self.requestState = .blockedByStudent
                    } else {
                        self.requestState = .blocked
                    }
                }
            } else {
                self.requestState = .idle
                self.currentRequestID = nil
            }
            
        } catch {
            print("Error loading data: \(error)")
            self.alertMessage = error.localizedDescription
        }
        isLoading = false
    }
    
    func sendRequest() async {
        guard let currentUser = authManager.user else { return }
        do {
            try await communityManager.sendRequest(from: currentUser, to: instructorID)
            self.alertMessage = "Your request has been successfully sent!"
            self.showSuccessAlert = true
            await loadData()
        } catch let error as CommunityManager.RequestError {
            self.alertMessage = error.localizedDescription
            if error == .alreadyPending { self.requestState = .pending }
            if error == .alreadyApproved { self.requestState = .approved }
            if error == .blocked { self.requestState = .blocked }
        } catch {
            self.alertMessage = error.localizedDescription
        }
    }
    
    func cancelRequest() async {
        guard let requestID = currentRequestID else {
            self.requestState = .idle
            return
        }
        
        do {
            try await communityManager.cancelRequest(requestID: requestID)
            self.alertMessage = "Your request has been cancelled."
            self.showSuccessAlert = true
            self.requestState = .idle
            self.currentRequestID = nil
        } catch {
            self.alertMessage = error.localizedDescription
        }
    }
    
    func blockInstructor() async {
        guard let student = authManager.user else { return }
        
        isLoading = true
        alertMessage = nil
        do {
            try await communityManager.blockInstructor(instructorID: instructorID, student: student)
            self.alertMessage = "You have blocked this instructor. They cannot be messaged and will be removed from your lists."
            self.showSuccessAlert = true
            await loadData()
        } catch {
            self.alertMessage = error.localizedDescription
        }
        isLoading = false
    }
    
    func unblockInstructor() async {
        guard let studentID = authManager.user?.id else { return }
        
        isLoading = true
        alertMessage = nil
        do {
            try await communityManager.unblockInstructor(instructorID: instructorID, studentID: studentID)
            self.alertMessage = "You have unblocked this instructor. You can now send them a new request."
            self.showSuccessAlert = true
            await loadData()
        } catch {
            self.alertMessage = error.localizedDescription
        }
        isLoading = false
    }
}

// MARK: - Subviews

private struct ProfileHeaderCard: View {
    let user: AppUser
    let isStudent: Bool
    let requestState: RequestButtonState
    let onActionTap: () -> Void
    
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
    
    // Logic for Button Appearance
    var buttonConfig: (text: String, color: Color, isDisabled: Bool) {
        switch requestState {
        case .idle: return ("Become a Student", .primaryBlue, false)
        case .pending: return ("Request Pending", .gray, false) // Can tap to cancel
        case .approved: return ("Approved Student", .accentGreen, true)
        case .denied: return ("Request Denied (Re-apply)", .orange, false)
        case .blocked: return ("Blocked by Instructor", .red, true)
        case .blockedByStudent: return ("You Blocked This User", .gray, true)
        }
    }
    
    var body: some View {
        VStack(spacing: 12) {
            AsyncImage(url: profileImageURL) { phase in
                if let image = phase.image {
                    image.resizable().scaledToFill()
                } else {
                    Image(systemName: "person.crop.circle.fill").resizable().foregroundColor(.secondary)
                }
            }
            .frame(width: 100, height: 100)
            .background(Color(.systemGray5))
            .clipShape(Circle())
            .overlay(Circle().stroke(Color.primaryBlue, lineWidth: 3))
            .padding(.top, 20)
            
            Text(user.name ?? "User Name")
                .font(.system(size: 22, weight: .semibold))
                .foregroundColor(.primary)
            
            Text(user.role.rawValue.capitalized)
                .font(.system(size: 15))
                .foregroundColor(.secondary)
            
            HStack(spacing: 4) {
                Image(systemName: "mappin.and.ellipse")
                Text(locationString)
            }
            .font(.system(size: 14))
            .foregroundColor(Color.primaryBlue)
            
            // --- ACTION BUTTON IN HEADER ---
            if isStudent {
                Button(action: onActionTap) {
                    Text(buttonConfig.text)
                        .font(.headline).bold()
                        .padding(.vertical, 10)
                        .padding(.horizontal, 30)
                        .background(buttonConfig.color)
                        .foregroundColor(.white)
                        .cornerRadius(20)
                        .shadow(color: buttonConfig.color.opacity(0.3), radius: 5, x: 0, y: 3)
                }
                .disabled(buttonConfig.isDisabled)
                .padding(.top, 8)
            }
            // -----------------------------
            
            Spacer().frame(height: 12)
        }
        .frame(maxWidth: .infinity)
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.08), radius: 4, y: 2)
    }
}

private struct ContactCard: View {
    let user: AppUser
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("CONTACT")
                .font(.system(size: 13, weight: .bold))
                .foregroundColor(.secondary)
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 8)
            Divider().padding(.horizontal, 16)
            ContactRow(icon: "envelope.fill", label: "Email", value: user.email)
            ContactRow(icon: "phone.fill", label: "Phone", value: user.phone ?? "Not provided")
            ContactRow(icon: "mappin.and.ellipse", label: "Address", value: user.address ?? "Not provided")
        }
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.08), radius: 4, y: 2)
    }
}

private struct RateHighlightCard: View {
    let user: AppUser
    var body: some View {
        VStack(spacing: 4) {
            Text("Hourly Rate")
                .font(.system(size: 15))
                .foregroundColor(.white.opacity(0.9))
            Text(user.hourlyRate ?? 0.0, format: .currency(code: "GBP"))
                .font(.system(size: 36, weight: .bold))
                .foregroundColor(.white)
            Text("per hour")
                .font(.system(size: 15))
                .foregroundColor(.white.opacity(0.9))
        }
        .padding(20)
        .frame(maxWidth: .infinity)
        .background(
            LinearGradient(
                gradient: Gradient(colors: [Color.primaryBlue, Color(red: 0.35, green: 0.34, blue: 0.84)]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .cornerRadius(16)
        .shadow(color: Color.primaryBlue.opacity(0.4), radius: 8, y: 4)
    }
}

private struct EducationCard: View {
    let education: [EducationEntry]?
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("EDUCATION OR CERTIFICATION")
                .font(.system(size: 13, weight: .bold))
                .foregroundColor(.secondary)
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 8)
            Divider().padding(.horizontal, 16)
            if let education = education, !education.isEmpty {
                VStack(alignment: .leading, spacing: 14) {
                    ForEach(education) { entry in
                        EduRow(title: entry.title, subtitle: entry.subtitle, years: entry.years)
                        if entry.id != education.last?.id {
                            Divider().padding(.horizontal, 16)
                        }
                    }
                }
                .padding(.vertical, 14)
            } else {
                Text("No education or certifications added.")
                    .font(.system(size: 15))
                    .foregroundColor(.secondary)
                    .padding(16)
            }
        }
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.08), radius: 4, y: 2)
    }
}

private struct EduRow: View {
    let title: String
    let subtitle: String
    let years: String
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.system(size: 17, weight: .semibold))
                .foregroundColor(.primary)
            Text(subtitle)
                .font(.system(size: 15))
                .foregroundColor(Color.primaryBlue)
            Text(years)
                .font(.system(size: 13))
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 16)
    }
}

private struct AboutCard: View {
    let aboutText: String?
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("ABOUT")
                .font(.system(size: 13, weight: .bold))
                .foregroundColor(.secondary)
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 8)
            Divider().padding(.horizontal, 16)
            if let text = aboutText, !text.isEmpty {
                Text(text)
                    .font(.system(size: 16))
                    .foregroundColor(.primary)
                    .lineSpacing(4)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 16)
            } else {
                Text("No bio added.")
                    .font(.system(size: 15))
                    .foregroundColor(.secondary)
                    .padding(16)
            }
        }
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.08), radius: 4, y: 2)
    }
}

private struct ExpertiseCard: View {
    let skills: [String]?
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("EXPERTISE")
                .font(.system(size: 13, weight: .bold))
                .foregroundColor(.secondary)
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 8)
            Divider().padding(.horizontal, 16)
            if let skills = skills, !skills.isEmpty {
                FlowLayout(alignment: .leading, spacing: 8) {
                    ForEach(skills, id: \.self) { skill in
                        Text(skill)
                            .font(.system(size: 14, weight: .medium))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color(.systemGray5))
                            .cornerRadius(12)
                            .foregroundColor(.primary)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 16)
            } else {
                Text("No skills added.")
                    .font(.system(size: 15))
                    .foregroundColor(.secondary)
                    .padding(16)
            }
        }
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.08), radius: 4, y: 2)
    }
}
