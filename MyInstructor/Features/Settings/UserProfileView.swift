//
//  UserProfileView.swift
//  MyInstructor
//
//  (REVISED FILE - Header now styled as a card matching other sections)
//

import SwiftUI

/// This is the main profile display view, redesigned to match the card-based UI image.
/// It shows user information in a read-only format and links to the edit page.
struct UserProfileView: View {
    @EnvironmentObject var authManager: AuthManager
    
    var body: some View {
        ScrollView {
            VStack(spacing: 25) {
                
                // --- 1. HEADER (now a card) ---
                ProfileHeaderCard()
                    .padding(.horizontal)
                
                // --- 2. EDIT PROFILE BUTTON ---
                NavigationLink(destination: ProfileView()) {
                    Text("Edit Profile")
                        .font(.headline).bold()
                        .padding(.vertical, 12)
                        .frame(maxWidth: .infinity)
                        .background(Color.secondaryGray)
                        .foregroundColor(.textDark)
                        .cornerRadius(10)
                }
                .padding(.horizontal)

                // --- 3. INFO CARDS ---
                
                // Contact Info Card
                ContactInfoCard(
                    email: authManager.user?.email,
                    phone: authManager.user?.phone,
                    address: authManager.user?.address
                )
                .padding(.horizontal)
                
                // Instructor: Hourly Rate Card
                if authManager.role == .instructor {
                    RateCard(rate: authManager.user?.hourlyRate ?? 0.0)
                        .padding(.horizontal)
                }

                // Education Card
                EducationCard()
                    .padding(.horizontal)
                
                // About Me Card
                AboutCard()
                    .padding(.horizontal)

                // Expertise Card
                ExpertiseCard()
                    .padding(.horizontal)
                
                Spacer()
            }
            .padding(.bottom, 20)
        }
        .navigationTitle("Your Profile")
        .navigationBarTitleDisplayMode(.inline)
        .background(Color(.systemGroupedBackground))
    }
}

// MARK: - HEADER CARD (matches other cards)
private struct ProfileHeaderCard: View {
    @EnvironmentObject var authManager: AuthManager
    
    private var profileImageURL: URL? {
        guard let urlString = authManager.user?.photoURL, !urlString.isEmpty else { return nil }
        return URL(string: urlString)
    }
    
    private var locationString: String {
        if let address = authManager.user?.address, !address.isEmpty {
            return address.components(separatedBy: ",").first ?? "Location N/A"
        }
        return "Location N/A"
    }
    
    var body: some View {
        VStack(spacing: 12) {
            // Profile Picture
            AsyncImage(url: profileImageURL) { phase in
                if let image = phase.image {
                    image
                        .resizable()
                        .scaledToFill()
                } else {
                    Image(systemName: "person.crop.circle.fill")
                        .resizable()
                        .scaledToFit()
                        .foregroundColor(.secondaryGray)
                }
            }
            .frame(width: 100, height: 100)
            .background(Color.secondaryGray.opacity(0.3))
            .clipShape(Circle())
            .overlay(Circle().stroke(Color.primaryBlue, lineWidth: 2))
            .padding(.top, 20)
            
            // Name
            Text(authManager.user?.name ?? "User Name")
                .font(.largeTitle).bold()
                .foregroundColor(.textDark)
            
            // Location
            HStack {
                Image(systemName: "mappin.and.ellipse")
                Text(locationString)
            }
            .font(.subheadline)
            .foregroundColor(.textLight)
            .padding(.bottom, 12)
        }
        .frame(maxWidth: .infinity)
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.05), radius: 5, y: 2)
    }
}

// MARK: - Base Card View
private struct ProfileCard<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(title.uppercased())
                .font(.caption).bold()
                .foregroundColor(.textLight)
                .padding([.horizontal, .top], 20)
                .padding(.bottom, 10)
            
            Divider()
            
            content
                .padding(20)
        }
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.05), radius: 5, y: 2)
    }
}

// MARK: - Card 1: Contact Info
private struct ContactInfoCard: View {
    var email: String?
    var phone: String?
    var address: String?
    
    var body: some View {
        ProfileCard(title: "Contact") {
            VStack(spacing: 20) {
                ContactInfoRow(
                    icon: "envelope.fill",
                    label: "Email",
                    value: email ?? "Not provided"
                )
                ContactInfoRow(
                    icon: "phone.fill",
                    label: "Phone",
                    value: phone ?? "Not provided"
                )
                ContactInfoRow(
                    icon: "mappin.and.ellipse",
                    label: "Address",
                    value: address ?? "Not provided"
                )
            }
        }
    }
}

// Helper for ContactInfoCard
private struct ContactInfoRow: View {
    let icon: String
    let label: String
    let value: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 15) {
            Image(systemName: icon)
                .font(.body)
                .frame(width: 20)
                .foregroundColor(.primaryBlue)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.subheadline)
                    .foregroundColor(.textDark)
                Text(value)
                    .font(.callout)
                    .foregroundColor(.textLight)
                    .lineLimit(2)
            }
            Spacer()
        }
    }
}

// MARK: - Card 2: Hourly Rate (Special)
private struct RateCard: View {
    let rate: Double
    
    var body: some View {
        VStack(spacing: 4) {
            Text("Hourly Rate")
                .font(.subheadline)
            
            Text(rate, format: .currency(code: "GBP"))
                .font(.system(size: 36, weight: .bold))
            
            Text("per hour")
                .font(.caption)
        }
        .padding(20)
        .frame(maxWidth: .infinity)
        .foregroundColor(.white)
        .background(
            LinearGradient(
                gradient: Gradient(colors: [Color.primaryBlue, Color(red: 0.25, green: 0.25, blue: 0.8)]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .cornerRadius(12)
        .shadow(color: Color.primaryBlue.opacity(0.4), radius: 8, y: 4)
    }
}

// MARK: - Card 3: Education
private struct EducationCard: View {
    var body: some View {
        ProfileCard(title: "Education") {
            VStack(spacing: 15) {
                EducationRow(
                    school: "ADI Certified",
                    degree: "Approved Driving Instructor",
                    years: "2018 - Present"
                )
                Divider()
                EducationRow(
                    school: "RoSPA Advanced Drivers",
                    degree: "Gold Standard Driving",
                    years: "2020"
                )
            }
        }
    }
}

// Helper for EducationCard
private struct EducationRow: View {
    let school: String
    let degree: String
    let years: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(school)
                .font(.headline)
                .foregroundColor(.textDark)
            Text(degree)
                .font(.subheadline)
                .foregroundColor(.primaryBlue)
            Text(years)
                .font(.caption)
                .foregroundColor(.textLight)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Card 4: About
private struct AboutCard: View {
    var body: some View {
        ProfileCard(title: "About") {
            Text("Passionate driving instructor with 8+ years of experience. Expert in teaching nervous drivers, parking, and test prep. I make complex topics simple using real-world examples.")
                .font(.body)
                .foregroundColor(.textLight)
                .lineSpacing(5)
        }
    }
}

// MARK: - Card 5: Expertise
private struct ExpertiseCard: View {
    let skills = ["Nervous Drivers", "Parallel Parking", "Roundabouts", "Motorway Driving", "Manual Transmission", "Defensive Driving", "Test Prep"]
    
    var body: some View {
        ProfileCard(title: "Expertise") {
            FlowLayout(alignment: .leading, spacing: 8) {
                ForEach(skills, id: \.self) { skill in
                    Text(skill)
                        .font(.caption).bold()
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(Color.secondaryGray)
                        .foregroundColor(.textDark)
                        .cornerRadius(18)
                }
            }
        }
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
        
        for size in sizes {
            if lineWidth + size.width + spacing > proposal.width ?? 0 {
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
            if x + sizes[index].width > bounds.maxX {
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
