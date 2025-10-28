//
//  UserProfileView.swift
//  MyInstructor
//
//  Exact iOS-style replica of the HTML/CSS version
//

import SwiftUI

struct UserProfileView: View {
    @EnvironmentObject var authManager: AuthManager
    @Environment(\.colorScheme) var colorScheme

    // Get the primaryBlue color from your app's custom color palette
    private var appBlue: Color {
        return Color.primaryBlue
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                
                // Profile Header Card
                ProfileHeaderCard()
                    .padding(.horizontal)
                    .padding(.top, 16) // Added padding

                // Contact Card
                ContactCard()
                    .padding(.horizontal)

                // Hourly Rate Card
                if authManager.role == .instructor {
                    RateHighlightCard()
                        .padding(.horizontal)
                }

                // Education Card
                // These cards now use the real data from AuthManager
                EducationCard(education: authManager.user?.education)
                    .padding(.horizontal)

                // About Card
                AboutCard(aboutText: authManager.user?.aboutMe)
                    .padding(.horizontal)

                // Expertise Card
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
        .background(Color(.systemBackground)) // Use white background
        .toolbar {
            // --- THIS IS THE NEW "EDIT PROFILE" BUTTON ---
            ToolbarItem(placement: .navigationBarTrailing) {
                NavigationLink(destination: ProfileView()) {
                    Text("Edit Profile")
                        .bold()
                        .foregroundColor(appBlue) // Use the app's primary color
                }
            }
        }
        // "Back" button ToolbarItem has been removed, so the default one will show
    }
}

// MARK: - Profile Header Card (exact match)
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
            .overlay(Circle().stroke(Color.primaryBlue, lineWidth: 3)) // Use app color
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
            .foregroundColor(Color.primaryBlue) // Use app color
            .padding(.bottom, 12)
        }
        .frame(maxWidth: .infinity)
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.08), radius: 4, y: 2)
    }
}

// MARK: - Contact Card
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

private struct ContactRow: View {
    let icon: String
    let label: String
    let value: String

    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .frame(width: 32, height: 32)
                .background(Color.primaryBlue) // Use app color
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

// MARK: - Hourly Rate Highlight
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

// MARK: - Education Card
private struct EducationCard: View {
    let education: [EducationEntry]? // <-- Accepts real data
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("EDUCATION")
                .font(.system(size: 13, weight: .bold))
                .foregroundColor(.secondary)
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 8)

            Divider().padding(.horizontal, 16)

            // --- Updated Logic ---
            if let education = education, !education.isEmpty {
                VStack(alignment: .leading, spacing: 14) {
                    ForEach(education) { entry in
                        EduRow(school: entry.school, degree: entry.degree, years: entry.years)
                        if entry.id != education.last?.id {
                            Divider().padding(.horizontal, 16)
                        }
                    }
                }
                .padding(.vertical, 14)
            } else {
                Text("No education details added. Tap 'Edit Profile' to add them.")
                    .font(.system(size: 15))
                    .foregroundColor(.secondary)
                    .padding(16)
            }
            // --- End Logic ---
        }
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.08), radius: 4, y: 2)
    }
}

private struct EduRow: View {
    let school: String
    let degree: String
    let years: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(school)
                .font(.system(size: 17, weight: .semibold))
                .foregroundColor(.primary)
            Text(degree)
                .font(.system(size: 15))
                .foregroundColor(Color.primaryBlue) // Use app color
            Text(years)
                .font(.system(size: 13))
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 16)
    }
}

// MARK: - About Card
private struct AboutCard: View {
    let aboutText: String? // <-- Accepts real data

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("ABOUT")
                .font(.system(size: 13, weight: .bold))
                .foregroundColor(.secondary)
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 8)

            Divider().padding(.horizontal, 16)

            // --- Updated Logic ---
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
            // --- End Logic ---
        }
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.08), radius: 4, y: 2)
    }
}

// MARK: - Expertise Card
private struct ExpertiseCard: View {
    let skills: [String]? // <-- Accepts real data

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("EXPERTISE")
                .font(.system(size: 13, weight: .bold))
                .foregroundColor(.secondary)
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 8)

            Divider().padding(.horizontal, 16)

            // --- Updated Logic ---
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
                Text("No skills added. Tap 'Edit Profile' to add your expertise.")
                    .font(.system(size: 15))
                    .foregroundColor(.secondary)
                    .padding(16)
            }
            // --- End Logic ---
        }
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.08), radius: 4, y: 2)
    }
}

// MARK: - Helper: FlowLayout (for skills)
private struct FlowLayout: Layout {
    var alignment: Alignment
    var spacing: CGFloat

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let sizes = subviews.map { $0.sizeThatFits(.unspecified) }
        var totalHeight: CGFloat = 0
        var totalWidth: CGFloat = 0
        
        var lineWidth: CGFloat = 0
        var lineHeight: CGFloat = 0

        // Calculate size based on a proposal, respecting padding
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

// MARK: - Preview
struct UserProfileView_Previews: PreviewProvider {
    // --- THIS IS THE CORRECTED PREVIEW CODE ---
    // 1. mockAuthManager is now a static var on the struct
    static var mockAuthManager: AuthManager {
        let manager = AuthManager()
        manager.user = AppUser(id: "123", email: "emma.richardson@edu.com", name: "Emma Richardson", role: .instructor)
        manager.user?.phone = "+1 (555) 123-4567"
        manager.user?.address = "123 Education St, SF"
        manager.user?.hourlyRate = 85.0
        manager.user?.aboutMe = "Passionate driving instructor with 8+ years of experience."
        manager.user?.education = [EducationEntry(school: "ADI Certified", degree: "Approved Driving Instructor", years: "2018")]
        manager.user?.expertise = ["Nervous Drivers", "Parallel Parking", "Test Prep"]
        return manager
    }

    // 2. previews var now *uses* mockAuthManager
    static var previews: some View {
        NavigationView {
            UserProfileView()
                .environmentObject(mockAuthManager) // Use the mock manager
        }
        .preferredColorScheme(.light)

        NavigationView {
            UserProfileView()
                .environmentObject(mockAuthManager) // Use the mock manager
        }
        .preferredColorScheme(.dark)
    }
    // --- END CORRECTION ---
}
