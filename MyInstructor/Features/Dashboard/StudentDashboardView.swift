import SwiftUI

struct StudentDashboardView: View {
    @EnvironmentObject var authManager: AuthManager
    @EnvironmentObject var dataService: DataService
    @EnvironmentObject var communityManager: CommunityManager
    @EnvironmentObject var chatManager: ChatManager
    @EnvironmentObject var notificationManager: NotificationManager

    @State private var upcomingLesson: Lesson?
    @State private var progress: Double = 0.0
    @State private var latestFeedback: String = ""
    @State private var paymentDue: Bool = false
    @State private var isLoading = true
    
    // Notification count now reflects unread app notifications + requests
    var notificationCount: Int {
        notificationManager.notifications.filter { !$0.isRead }.count
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    DashboardHeader(notificationCount: notificationCount)
                    
                    if isLoading {
                        ProgressView("Loading Dashboard...").padding(.top, 50).frame(maxWidth: .infinity)
                    } else {
                        // Lesson Card
                        if let lesson = upcomingLesson {
                            NavigationLink(destination: LessonDetailsView(lesson: lesson)) {
                                DashboardCard(title: "Upcoming Lesson", systemIcon: "car.fill", accentColor: .accentGreen, content: {
                                    StudentUpcomingLessonContent(lesson: lesson)
                                })
                            }.buttonStyle(.plain).padding(.horizontal)
                        } else {
                            DashboardCard(title: "Upcoming Lesson", systemIcon: "car.fill", accentColor: .accentGreen, content: {
                                StudentUpcomingLessonContent(lesson: nil)
                            }).padding(.horizontal)
                        }
                        
                        // Progress
                        DashboardCard(title: "Your Progress", systemIcon: "book.fill", accentColor: .primaryBlue, content: {
                            StudentProgressContent(progress: progress)
                        }).padding(.horizontal)
                        
                        // --- UPDATED: Clickable Feedback Card ---
                        NavigationLink(destination: StudentFeedbackListView(studentID: authManager.user?.id ?? "")) {
                            DashboardCard(title: "Latest Feedback", systemIcon: "note.text", accentColor: .orange, content: {
                                StudentFeedbackContent(feedback: latestFeedback)
                            })
                        }
                        .buttonStyle(.plain)
                        .padding(.horizontal)
                        // ----------------------------------------
                        
                        // Payment
                        if paymentDue { PaymentDueCard().padding(.horizontal) }
                    }
                    Spacer()
                }
            }
            .navigationTitle("Dashboard")
            .navigationBarHidden(true)
            .task {
                guard let studentID = authManager.user?.id else {
                    isLoading = false
                    return
                }
                // Start Listeners
                chatManager.listenForConversations(for: studentID)
                notificationManager.listenForNotifications(for: studentID)
                
                await fetchData()
            }
            .refreshable { await fetchData() }
        }
    }
    
    func fetchData() async {
        guard let studentID = authManager.user?.id else { isLoading = false; return }
        isLoading = true
        do {
            async let dataTask = dataService.fetchStudentDashboardData(for: studentID)
            let data = try await dataTask
            self.upcomingLesson = data.upcomingLesson
            self.progress = data.progress
            self.latestFeedback = data.latestFeedback
            self.paymentDue = data.paymentDue
            
            if let lesson = self.upcomingLesson {
                notificationManager.scheduleLessonReminders(lesson: lesson)
            }
        } catch { print("Failed: \(error)") }
        isLoading = false
    }
}

// ... (Sub-views) ...
struct StudentUpcomingLessonContent: View {
    let lesson: Lesson?
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let lesson = lesson {
                Text(lesson.topic).font(.title3).bold()
                HStack { Image(systemName: "calendar"); Text("\(lesson.startTime, style: .date) at \(lesson.startTime, style: .time)") }.font(.callout).foregroundColor(.textLight)
                HStack { Image(systemName: "mappin.and.ellipse"); Text(lesson.pickupLocation) }.font(.callout).foregroundColor(.textLight)
                Text("Tap to view details").font(.caption).foregroundColor(.primaryBlue).padding(.top, 4)
            } else {
                Text("No upcoming lessons scheduled.").font(.subheadline).bold().foregroundColor(.textLight)
            }
        }
    }
}

struct StudentProgressContent: View {
    let progress: Double
    var body: some View {
        HStack {
            CircularProgressView(progress: progress, color: .primaryBlue, size: 80).padding(.trailing, 20)
            VStack(alignment: .leading) {
                Text("\(Int(progress * 100))%").font(.largeTitle).bold().foregroundColor(.primaryBlue)
                Text("Overall Mastery").font(.headline)
                Text("As graded by your instructor").font(.caption).foregroundColor(.textLight)
            }
            Spacer()
        }
    }
}

struct StudentFeedbackContent: View {
    let feedback: String
    var body: some View {
        VStack(alignment: .leading) {
            if feedback.isEmpty {
                Text("No feedback notes yet.").font(.body).foregroundColor(.textLight)
            } else {
                Text(feedback).font(.body).lineLimit(3).foregroundColor(.primary)
                HStack {
                    Spacer()
                    // This text serves as a visual cue that the card is tappable
                    Text("View All History").font(.caption).bold().foregroundColor(.orange)
                }
            }
        }
    }
}

struct PaymentDueCard: View {
    var body: some View {
        HStack {
            Image(systemName: "exclamationmark.triangle.fill").foregroundColor(.warningRed)
            VStack(alignment: .leading) { Text("Payment Pending").font(.headline).foregroundColor(.warningRed); Text("Check 'Track Income'").font(.subheadline) }
            Spacer()
        }.padding(15).background(Color.warningRed.opacity(0.1)).cornerRadius(15).overlay(RoundedRectangle(cornerRadius: 15).stroke(Color.warningRed, lineWidth: 1))
    }
}
