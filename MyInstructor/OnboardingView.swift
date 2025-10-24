import SwiftUI

// MARK: - Onboarding View (Flow 2 - Redesigned Professional)
struct OnboardingView: View {
    let onComplete: () -> Void
    
    @State private var currentPage = 0
    let slides = [
        ("calendar.badge.plus", "Seamless Scheduling", "Effortlessly manage your lessons, appointments, and availability with an intuitive calendar. Stay organized and never miss a beat."),
        ("location.magnifyingglass", "Real-time Tracking", "Connect with your instructor or student through live location sharing. Enhance safety and streamline pickups with precision."),
        ("chart.line.uptrend.rectangle", "Progress & Payments", "Monitor your driving journey with detailed progress reports and easily track all payments. Achieve your goals with clear insights.")
    ]
    
    var body: some View {
        VStack {
            TabView(selection: $currentPage) {
                ForEach(slides.indices, id: \.self) { index in
                    OnboardingSlideRedesigned(
                        imageName: slides[index].0,
                        title: slides[index].1,
                        description: slides[index].2
                    )
                        .tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never)) // Hide default page indicator
            .padding(.top, 40) // Give some space from the top
            
            Spacer() // Push content to center
            
            PageControl(numberOfPages: slides.count, currentPage: $currentPage)
                .padding(.bottom, 30) // More padding for page control
            
            HStack(spacing: 20) {
                // Skip Button
                Button("Skip") {
                    completeOnboarding()
                }
                .font(.headline)
                .foregroundColor(.textLight)
                .padding(.horizontal)

                Spacer()

                // Get Started / Next Button
                Button(currentPage < slides.count - 1 ? "Next" : "Get Started") {
                    if currentPage < slides.count - 1 {
                        withAnimation(.easeInOut) {
                            currentPage += 1
                        }
                    } else {
                        completeOnboarding()
                    }
                }
                .buttonStyle(.borderedProminent) // Modern button style
                .tint(.primaryBlue) // Use accent color
                .controlSize(.large) // Make it more prominent
                .cornerRadius(12) // Slightly rounded corners
            }
            .padding(.horizontal, 30)
            .padding(.bottom, 40) // Increase bottom padding
        }
        .background(Color(.systemGray6).ignoresSafeArea()) // Subtle light gray background
    }
    
    private func completeOnboarding() {
        UserDefaults.standard.set(true, forKey: "hasSeenOnboarding")
        onComplete()
    }
}

// MARK: - Supporting Onboarding Structs (Redesigned Slide)

struct OnboardingSlideRedesigned: View {
    let imageName: String
    let title: String
    let description: String
    
    var body: some View {
        VStack(spacing: 25) { // Increased spacing
            Image(systemName: imageName)
                .resizable()
                .scaledToFit()
                .frame(width: 150, height: 150) // Larger icon
                .foregroundColor(.primaryBlue)
                .padding(30)
                .background(
                    Circle()
                        .fill(Color.primaryBlue.opacity(0.1)) // Subtle blue circle background
                        .shadow(color: Color.black.opacity(0.05), radius: 10, x: 0, y: 5) // Soft shadow
                )
                .padding(.bottom, 20) // Space after icon
            
            Text(title)
                .font(.largeTitle) // More impactful title
                .fontWeight(.heavy) // Bold weight
                .foregroundColor(.textDark)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 20)
            
            Text(description)
                .font(.body) // Clear body text
                .foregroundColor(.textLight)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 30)
                .lineLimit(3) // Ensure description fits well
            
            Spacer() // Pushes content upwards
        }
    }
}

// PageControl struct remains the same as it's already functional and clean
struct PageControl: View {
    let numberOfPages: Int
    @Binding var currentPage: Int
    
    var body: some View {
        HStack(spacing: 8) {
            ForEach(0..<numberOfPages, id: \.self) { index in
                Circle()
                    .fill(index == currentPage ? Color.primaryBlue : Color.secondaryGray)
                    .frame(width: 10, height: 10)
                    .animation(.easeInOut, value: currentPage)
            }
        }
    }
}
