import SwiftUI

// MARK: - Onboarding View (Flow 2 - Redesigned Professional)
struct OnboardingView: View {
    let onComplete: () -> Void
    
    @State private var currentPage = 0
    // Updated icon names to use custom assets: SeamlessScheduling, RealtimeTracking, ProgressPayments
    let slides = [
        ("SeamlessScheduling", "Seamless Scheduling", "Effortlessly manage your lessons, appointments, and availability with an intuitive calendar. Stay organized and never miss a beat.", Color.primaryBlue),
        ("RealtimeTracking", "Real-time Tracking", "Connect with your instructor or student through live location sharing. Enhance safety and streamline pickups with precision.", Color.accentGreen),
        ("ProgressPayments", "Progress & Payments", "Monitor your driving journey with detailed progress reports and easily track all payments. Achieve your goals with clear insights.", Color.orange)
    ]
    
    var body: some View {
        VStack {
            TabView(selection: $currentPage) {
                ForEach(slides.indices, id: \.self) { index in
                    OnboardingSlideRedesigned(
                        imageName: slides[index].0,
                        title: slides[index].1,
                        description: slides[index].2,
                        accentColor: slides[index].3 // Pass the specific accent color
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
    let accentColor: Color
    
    var body: some View {
        VStack(spacing: 25) { // Increased spacing
            Spacer() // ADDED: Top Spacer to center content vertically
            
            // Using Image(imageName) to load custom assets
            Image(imageName)
                .resizable()
                .scaledToFit()
                .frame(width: 120, height: 120) // Increased size
                .foregroundColor(accentColor) // Icon color matches accent
                // Background and extra padding removed
                .padding(.bottom, 20) // Space after icon
            
            Text(title)
                .font(.largeTitle)
                .fontWeight(.heavy)
                .foregroundColor(.textDark)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 20)
            
            Text(description)
                .font(.body)
                .foregroundColor(.textLight)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 30)
                .lineLimit(3)
            
            Spacer() // Existing: Bottom Spacer (now balances the top Spacer)
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
