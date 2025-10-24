import SwiftUI

// Flow Item 6: Student Dashboard
struct StudentDashboardView: View {
    @EnvironmentObject var authManager: AuthManager
    @EnvironmentObject var dataService: DataService
    
    // Mock student ID, should be derived from authManager.user?.id
    private let studentID = "student_abc" 

    @State private var upcomingLesson: Lesson?
    @State private var progress: Double = 0.65
    @State private var latestFeedback: String = ""
    @State private var paymentDue: Bool = false
    @State private var isLoading = true
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    DashboardHeader() // Shared Component
                    
                    if isLoading {
                        ProgressView("Loading Dashboard...")
                            .padding(.top, 50)
                            .frame(maxWidth: .infinity)
                    } else {
                        // Upcoming Lesson Card
                        DashboardCard(title: "Upcoming Lesson", systemIcon: "car.fill", accentColor: .accentGreen, content: {
                            StudentUpcomingLessonContent(lesson: upcomingLesson)
                        })
                        .padding(.horizontal)
                        
                        // Progress Summary
                        DashboardCard(title: "Your Progress", systemIcon: "book.fill", accentColor: .primaryBlue, content: {
                            StudentProgressContent(progress: progress)
                        })
                        .padding(.horizontal)
                        
                        // Latest Feedback
                        DashboardCard(title: "Latest Feedback", systemIcon: "note.text", accentColor: .orange, content: {
                            StudentFeedbackContent(feedback: latestFeedback)
                        })
                        .padding(.horizontal)
                        
                        // Payment Due (Conditional Card)
                        if paymentDue {
                            PaymentDueCard()
                                .padding(.horizontal)
                        }
                    }
                    
                    Spacer()
                }
            }
            .navigationTitle("Dashboard")
            .navigationBarHidden(true)
            .task {
                await fetchData()
            }
            .refreshable {
                await fetchData()
            }
        }
    }
    
    func fetchData() async {
        isLoading = true
        // NOTE: Use the actual studentID here: authManager.user?.id ?? studentID
        do {
            let data = try await dataService.fetchStudentDashboardData(for: studentID)
            self.upcomingLesson = data.upcomingLesson
            self.progress = data.progress
            self.latestFeedback = data.latestFeedback
            self.paymentDue = data.paymentDue
        } catch {
            print("Failed to fetch student data: \(error)")
        }
        isLoading = false
    }
}

// MARK: - Sub-Views for Student Dashboard

struct StudentUpcomingLessonContent: View {
    let lesson: Lesson?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let lesson = lesson {
                Text(lesson.topic)
                    .font(.title3).bold()
                
                HStack {
                    Image(systemName: "calendar")
                    Text("\(lesson.startTime, style: .date) at \(lesson.startTime, style: .time)")
                }
                .font(.callout)
                .foregroundColor(.textLight)
                
                HStack {
                    Image(systemName: "person.circle.fill")
                    Text("Instructor: Mr. Smith") // Placeholder
                }
                .font(.callout)
                .foregroundColor(.textLight)
            } else {
                Text("No upcoming lessons scheduled.")
                    .font(.subheadline).bold()
                    .foregroundColor(.textLight)
            }
        }
    }
}

struct StudentProgressContent: View {
    let progress: Double
    var body: some View {
        HStack {
            CircularProgressView(progress: progress, color: .primaryBlue, size: 80)
                .padding(.trailing, 20)
            
            VStack(alignment: .leading) {
                Text("\(Int(progress * 100))%")
                    .font(.largeTitle).bold()
                    .foregroundColor(.primaryBlue)
                Text("Overall Mastery")
                    .font(.headline)
                Text("View detailed skill breakdown →")
                    .font(.caption)
                    .foregroundColor(.textLight)
            }
            Spacer()
        }
    }
}

struct StudentFeedbackContent: View {
    let feedback: String
    var body: some View {
        VStack(alignment: .leading) {
            Text(feedback)
                .font(.body)
                .lineLimit(3)
            HStack {
                Spacer()
                Text("Read Latest Note →")
                    .font(.caption).bold()
                    .foregroundColor(.orange)
            }
        }
    }
}

struct PaymentDueCard: View {
    var body: some View {
        HStack {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(.warningRed)
            VStack(alignment: .leading) {
                Text("£45.00 Payment Pending")
                    .font(.headline).foregroundColor(.warningRed)
                Text("Tap to review and pay now")
                    .font(.subheadline)
            }
            Spacer()
            Image(systemName: "chevron.right").foregroundColor(.textLight)
        }
        .padding(15)
        .background(Color.warningRed.opacity(0.1))
        .cornerRadius(15)
        .overlay(
            RoundedRectangle(cornerRadius: 15)
                .stroke(Color.warningRed, lineWidth: 1)
        )
    }
}