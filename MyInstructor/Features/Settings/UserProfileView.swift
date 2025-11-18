// File: arafatrahman/myinstructor/MyInstructor-main/MyInstructor/Features/Settings/UserProfileView.swift
// --- UPDATED: Removed 'private' from ContactRow to fix redeclaration error ---
// --- UPDATED: Removed the private FlowLayout struct at the end ---

import SwiftUI

struct UserProfileView: View {
    @EnvironmentObject var authManager: AuthManager
    @Environment(\.colorScheme) var colorScheme

    private var appBlue: Color {
        return Color.primaryBlue
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                ProfileHeaderCard()
                    .padding(.horizontal)
                    .padding(.top, 16)

                ContactCard()
                    .padding(.horizontal)

                if authManager.role == .instructor {
                    RateHighlightCard()
                        .padding(.horizontal)
                }

                EducationCard(education: authManager.user?.education)
                    .padding(.horizontal)

                AboutCard(aboutText: authManager.user?.aboutMe)
                    .padding(.horizontal)

                if authManager.role == .instructor {
                    ExpertiseCard(skills: authManager.user?.expertise)
                        .padding(.horizontal)
                }

                Spacer(minLength: 20)
            }
            .padding(.bottom, 20)
        }
        .navigationTitle("Profile")
        .navigationBarTitleDisplayMode(.inline)
        .background(Color(.systemBackground))
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                NavigationLink(destination: ProfileView()) {
                    Text("Edit Profile")
                        .bold()
                        .foregroundColor(appBlue)
                }
            }
        }
    }
}

// MARK: - Profile Header Card (private)
private struct ProfileHeaderCard: View {
    @EnvironmentObject var authManager: AuthManager

    private var profileImageURL: URL? {
        guard let urlString = authManager.user?.photoURL, !urlString.isEmpty else { return nil }
        return URL(string: urlString)
    }

    private var locationString: String {
        if let address = authManager.user?.address, !address.isEmpty {
            return address.components(separatedBy: ",").first?.trimmingCharacters(in: .whitespaces) ?? "Location N/A"
        }
        return "Location N/A"
    }

    var body: some View {
        VStack(spacing: 12) {
            AsyncImage(url: profileImageURL) { phase in
                if let image = phase.image {
                    image
                        .resizable()
                        .scaledToFill()
                } else {
                    Image(systemName: "person.crop.circle.fill")
                        .resizable()
                        .foregroundColor(.secondary)
                }
            }
            .frame(width: 100, height: 100)
            .background(Color(.systemGray5))
            .clipShape(Circle())
            .overlay(Circle().stroke(Color.primaryBlue, lineWidth: 3))
            .padding(.top, 20)

            Text(authManager.user?.name ?? "User Name")
                .font(.system(size: 22, weight: .semibold))
                .foregroundColor(.primary)

            Text(authManager.role.rawValue.capitalized)
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

// MARK: - Contact Card (private)
private struct ContactCard: View {
    @EnvironmentObject var authManager: AuthManager

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("CONTACT")
                .font(.system(size: 13, weight: .bold))
                .foregroundColor(.secondary)
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 8)

            Divider().padding(.horizontal, 16)

            ContactRow(icon: "envelope.fill", label: "Email", value: authManager.user?.email ?? "Not provided")
            ContactRow(icon: "phone.fill", label: "Phone", value: authManager.user?.phone ?? "Not provided")
            ContactRow(icon: "mappin.and.ellipse", label: "Address", value: authManager.user?.address ?? "Not provided")
        }
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.08), radius: 4, y: 2)
    }
}

struct ContactRow: View {
    let icon: String
    let label: String
    let value: String

    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .frame(width: 32, height: 32)
                .background(Color.primaryBlue)
                .foregroundColor(.white)
                .cornerRadius(8)

            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
                Text(value)
                    .font(.system(size: 17, weight: .medium))
                    .foregroundColor(.primary)
            }
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color(.systemBackground))
    }
}

// MARK: - Hourly Rate Highlight (private)
private struct RateHighlightCard: View {
    @EnvironmentObject var authManager: AuthManager

    var body: some View {
        VStack(spacing: 4) {
            Text("Hourly Rate")
                .font(.system(size: 15))
                .foregroundColor(.white.opacity(0.9))

            Text(authManager.user?.hourlyRate ?? 0.0, format: .currency(code: "GBP"))
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

// MARK: - Education Card (private)
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
                Text("No education or certifications added. Tap 'Edit Profile' to add them.")
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

// MARK: - EduRow (private)
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

// MARK: - About Card (private)
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
                Text("No bio added. Tap 'Edit Profile' to add one.")
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

// MARK: - Expertise Card (private)
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
                // This will now use the central FlowLayout
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
                Text("No skills added. Tap 'Edit Profile' to add your expertise.")
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

// --- *** DELETED THE private struct FlowLayout FROM HERE *** ---
