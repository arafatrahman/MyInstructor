import SwiftUI

struct OnboardingView: View {
    // Callback to signal onboarding is done
    var onComplete: () -> Void
    
    @State private var currentPage = 0
    
    // --- UPDATED SLIDES (4 Items, SF Symbols) ---
    // Tuple Format: (SystemImageName, Title, Description, ThemeColor)
    let slides = [
        (
            "calendar.badge.clock",
            "Smart Scheduling",
            "Streamline your day with Quick Actions. Easily manage Lessons, Track Exams, and stay on top of your schedule.",
            Color.primaryBlue
        ),
        (
            "chart.pie.fill",
            "Finance & Analytics",
            "Take control of your earnings. Track Income, Expenses, and Payments while visualizing growth with powerful Analytics.",
            Color.accentGreen
        ),
        (
            "car.fill",
            "Fleet & Live Map",
            "Keep your vehicles road-ready with Service Books and Mileage Logs. Connect instantly with students via Live Map.",
            Color.orange
        ),
        (
            "folder.fill",
            "Digital Organizer",
            "Securely store important documents in your Digital Vault. Keep Contacts and detailed Student Notes all in one place.",
            Color.purple
        )
    ]
    
    var body: some View {
        ZStack {
            // Background Color (White for clean look)
            Color.white.ignoresSafeArea()
            
            VStack {
                // Top Bar with Skip Button
                HStack {
                    Spacer()
                    // Only show Skip if not on the last page
                    if currentPage < slides.count - 1 {
                        Button("Skip") {
                            completeOnboarding()
                        }
                        .font(.subheadline)
                        .foregroundColor(.textLight)
                        .padding(.trailing, 20)
                    } else {
                        // Placeholder to keep layout consistent
                        Text(" ").padding(.trailing, 20)
                    }
                }
                .padding(.top, 20)
                
                // Content TabView
                TabView(selection: $currentPage) {
                    ForEach(0..<slides.count, id: \.self) { index in
                        OnboardingSlideView(slide: slides[index])
                            .tag(index)
                    }
                }
                .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
                .animation(.easeInOut, value: currentPage)
                
                // Bottom Controls
                VStack(spacing: 20) {
                    // Custom Page Indicator
                    HStack(spacing: 8) {
                        ForEach(0..<slides.count, id: \.self) { index in
                            Circle()
                                .fill(currentPage == index ? slides[currentPage].3 : Color.gray.opacity(0.3))
                                .frame(width: 8, height: 8)
                                .scaleEffect(currentPage == index ? 1.2 : 1.0)
                                .animation(.spring(), value: currentPage)
                        }
                    }
                    .padding(.top, 10)
                    
                    // Main Action Button
                    Button {
                        if currentPage < slides.count - 1 {
                            withAnimation {
                                currentPage += 1
                            }
                        } else {
                            completeOnboarding()
                        }
                    } label: {
                        Text(currentPage == slides.count - 1 ? "Get Started" : "Next")
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(slides[currentPage].3) // Button color matches slide theme
                            .cornerRadius(12)
                            .shadow(color: slides[currentPage].3.opacity(0.4), radius: 8, x: 0, y: 4)
                    }
                    .padding(.horizontal, 30)
                    .padding(.bottom, 20)
                }
            }
        }
    }
    
    private func completeOnboarding() {
        // This action tells RootView to set 'hasSeenOnboarding' to true
        // RootView will then naturally show the AuthenticationView (Login)
        onComplete()
    }
}

// Subview for a single slide
struct OnboardingSlideView: View {
    let slide: (String, String, String, Color)
    
    var body: some View {
        VStack(spacing: 20) {
            Spacer()
            
            // --- UPDATED: Uses SF Symbols (System Images) ---
            Image(systemName: slide.0)
                .resizable()
                .scaledToFit()
                .frame(height: 120) // Fixed height for consistency
                .foregroundColor(slide.3) // Apply theme color to the icon
                .padding(40)
                .background(
                    Circle()
                        .fill(slide.3.opacity(0.1)) // Subtle background circle
                        .frame(width: 240, height: 240)
                )
                .padding(.horizontal, 20)
            
            Spacer()
            
            // Text Content
            VStack(spacing: 15) {
                Text(slide.1)
                    .font(.title).bold()
                    .foregroundColor(.textDark)
                    .multilineTextAlignment(.center)
                
                Text(slide.2)
                    .font(.body)
                    .foregroundColor(.textLight)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 30)
                    .lineSpacing(4)
            }
            .padding(.bottom, 40)
        }
    }
}
