// File: Features/Community/InstructorPublicProfileView.swift
import SwiftUI
import FirebaseFirestore

// A (simplified) public profile view for an instructor
struct InstructorPublicProfileView: View {
    @EnvironmentObject var authManager: AuthManager
    @EnvironmentObject var communityManager: CommunityManager
    
    let instructorID: String
    
    @State private var instructor: AppUser?
    @State private var isLoading = true
    @State private var requestSent = false
    @State private var errorMessage: String?
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                if let user = instructor {
                    // --- Profile Header ---
                    ProfileHeaderCard(user: user)
                        .padding(.top, 16)
                    
                    // --- About Card ---
                    AboutCard(aboutText: user.aboutMe)
                    
                    // --- Education Card ---
                    EducationCard(education: user.education)
                    
                    // --- Expertise Card ---
                    ExpertiseCard(skills: user.expertise)

                    // --- THE NEW REQUEST BUTTON ---
                    if authManager.role == .student {
                        Button {
                            Task {
                                if let currentUser = authManager.user {
                                    do {
                                        try await communityManager.sendRequest(from: currentUser, to: instructorID)
                                        self.requestSent = true
                                    } catch {
                                        self.errorMessage = error.localizedDescription
                                    }
                                }
                            }
                        } label: {
                            Text(requestSent ? "Request Sent!" : "Send Request to this Instructor")
                        }
                        .buttonStyle(.primaryDrivingApp)
                        .disabled(requestSent)
                        .padding(.horizontal)
                        .padding(.bottom, 20)
                        
                        if requestSent {
                            Text("The instructor will be notified. Once approved, they will appear in your contacts.")
                                .font(.caption)
                                .foregroundColor(.textLight)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal)
                        }
                    }
                    
                } else if isLoading {
                    ProgressView()
                        .padding(.top, 50)
                } else {
                    Text("Could not load instructor profile.")
                        .padding()
                }
            }
            .padding(.horizontal) // Padding for the cards
        }
        .navigationTitle(instructor?.name ?? "Profile")
        .navigationBarTitleDisplayMode(.inline)
        .background(Color(.systemGroupedBackground)) // Match form backgrounds
        .task {
            await fetchInstructorData()
        }
    }
    
    func fetchInstructorData() async {
        isLoading = true
        do {
            let doc = try await Firestore.firestore().collection("users")
                                    .document(instructorID).getDocument()
            self.instructor = try doc.data(as: AppUser.self)
        } catch {
            print("Error fetching user: \(error)")
            self.errorMessage = error.localizedDescription
        }
        isLoading = false
    }
}


// MARK: - Re-usable Profile Sub-views
// These are simplified, read-only versions of the views in UserProfileView.swift
// You should move these to a "Shared/Views" folder to avoid duplicating code.

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
                // You must also copy the FlowLayout struct from UserProfileView.swift
                // For simplicity, I will use a simple VStack here.
                VStack(alignment: .leading, spacing: 8) {
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
