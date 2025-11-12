// File: arafatrahman/myinstructor/MyInstructor-main/MyInstructor/Features/Community/InstructorPublicProfileView.swift
// --- UPDATED: Fixed logic to correctly show the "Re-apply" button after unblocking ---

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
                    ProfileHeaderCard(user: user)
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
                        // 1. Conditional Message Button
                        if requestState == .approved, let instructorAppUser = instructor {
                            NavigationLink(destination: ChatLoadingView(otherUser: instructorAppUser)) {
                                Image(systemName: "message.circle.fill")
                                    .font(.title3)
                                    .foregroundColor(appBlue)
                            }
                        }
                        
                        // --- *** THIS IS THE UPDATED SECTION *** ---
                        // 2. Existing Request Button
                        // Show the button only for these specific states:
                        if requestState == .idle || requestState == .pending || requestState == .denied || requestState == .blockedByStudent {
                            Button(action: handleRequestButtonTap) {
                                Text(buttonText)
                                    .bold()
                            }
                            .disabled(buttonIsDisabled)
                            .tint(requestState == .pending ? .red : (requestState == .blocked || requestState == .blockedByStudent ? .gray : appBlue))
                        }
                        // --- *** END OF UPDATE *** ---
                        
                        // 3. Block/Unblock Menu
                        // Don't show menu if instructor blocked you
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
    
    var buttonText: String {
        switch requestState {
        case .idle: return "Become a Student"
        case .pending: return "Cancel Request"
        case .approved: return "Approved"
        case .denied: return "Re-apply"
        case .blocked: return "Blocked by Instructor"
        case .blockedByStudent: return "Blocked"
        }
    }
    
    var buttonIsDisabled: Bool {
        return requestState == .approved || requestState == .blocked || requestState == .blockedByStudent || isLoading
    }
    
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
            
            // Find the highest-priority request for this instructor
            // (e.g., a "blocked" request overrides an old "approved" one)
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
                    // Check WHO blocked
                    if existingRequest.blockedBy == "student" {
                        self.requestState = .blockedByStudent
                    } else {
                        // Blocked by instructor (or old block)
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
        } catch let error as RequestError {
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
            await loadData() // Refresh the state
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
            await loadData() // Refresh the state
        } catch {
            self.alertMessage = error.localizedDescription
        }
        isLoading = false
    }
}


// ... (Rest of InstructorPublicProfileView.swift: ProfileHeaderCard, ContactCard, RateHighlightCard, etc. are unchanged) ...
// (These are all fine)

private struct ProfileHeaderCard: View {
    let user: AppUser
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
            .padding(.bottom, 12)
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
            // This now uses the shared ContactRow
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

private struct FlowLayout: Layout {
    var alignment: Alignment
    var spacing: CGFloat
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let sizes = subviews.map { $0.sizeThatFits(.unspecified) }
        var totalHeight: CGFloat = 0
        var totalWidth: CGFloat = 0
        var lineWidth: CGFloat = 0
        var lineHeight: CGFloat = 0
        let effectiveWidth = (proposal.width ?? 0) - (spacing * 2)
        for size in sizes {
            if lineWidth + size.width + spacing > effectiveWidth && lineWidth > 0 {
                totalHeight += lineHeight + spacing
                lineWidth = size.width
                lineHeight = size.height
            } else {
                lineWidth += size.width + spacing
                lineHeight = max(lineHeight, size.height)
            }
            totalWidth = max(totalWidth, lineWidth)
        }
        totalHeight += lineHeight
        return .init(width: totalWidth, height: totalHeight)
    }
    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let sizes = subviews.map { $0.sizeThatFits(.unspecified) }
        var (x, y) = (bounds.minX, bounds.minY)
        var lineHeight: CGFloat = 0
        for index in subviews.indices {
            if x + sizes[index].width > bounds.maxX && x > bounds.minX {
                x = bounds.minX
                y += lineHeight + spacing
                lineHeight = 0
            }
            subviews[index].place(
                at: .init(x: x, y: y),
                anchor: .topLeading,
                proposal: .init(sizes[index])
            )
            lineHeight = max(lineHeight, sizes[index].height)
            x += sizes[index].width + spacing
        }
    }
}
