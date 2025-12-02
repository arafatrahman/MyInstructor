// File: arafatrahman/myinstructor/MyInstructor-main/MyInstructor/Features/Dashboard/StudentDashboardView.swift
// --- UPDATED: Uses generic NotesListView ---

import SwiftUI

enum StudentDashboardSheet: Identifiable {
    case lessonStats
    case myInstructors
    case paymentHistory
    case findInstructor
    case logPractice
    case contacts
    case notes
    
    var id: Int { self.hashValue }
}

struct StudentDashboardView: View {
    @EnvironmentObject var authManager: AuthManager
    @EnvironmentObject var dataService: DataService
    @EnvironmentObject var communityManager: CommunityManager
    @EnvironmentObject var chatManager: ChatManager
    @EnvironmentObject var notificationManager: NotificationManager
    @EnvironmentObject var lessonManager: LessonManager

    @State private var upcomingLesson: Lesson?
    @State private var progress: Double = 0.0
    @State private var latestFeedback: String = ""
    @State private var paymentDue: Bool = false
    @State private var completedLessonsCount: Int = 0
    @State private var isLoading = true
    
    @State private var activeSheet: StudentDashboardSheet?
    
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
                        // --- TOP ROW ---
                        HStack(spacing: 15) {
                            if let lesson = upcomingLesson {
                                NavigationLink(destination: LessonDetailsView(lesson: lesson)) {
                                    StudentDashboardCard(
                                        title: "Next Lesson", systemIcon: "calendar.badge.clock", accentColor: .primaryBlue, fixedHeight: 150, backgroundColor: Color.primaryBlue.opacity(0.1),
                                        content: { VStack(alignment: .leading, spacing: 4) { Text(lesson.topic).font(.headline).lineLimit(1).foregroundColor(.primary); Text(lesson.startTime, style: .date).font(.caption).foregroundColor(.secondary); Text(lesson.startTime, style: .time).font(.caption).foregroundColor(.secondary) } }
                                    )
                                }.buttonStyle(.plain).frame(maxWidth: .infinity)
                            } else {
                                StudentDashboardCard(
                                    title: "Next Lesson", systemIcon: "calendar.badge.clock", accentColor: .primaryBlue, fixedHeight: 150, backgroundColor: Color.primaryBlue.opacity(0.1),
                                    content: { Text("No upcoming lessons.").font(.caption).foregroundColor(.secondary) }
                                ).frame(maxWidth: .infinity)
                            }
                            
                            StudentDashboardCard(
                                title: "Lessons Taken", systemIcon: "checkmark.circle.fill", accentColor: .accentGreen, fixedHeight: 150, backgroundColor: Color.accentGreen.opacity(0.1),
                                content: { VStack(alignment: .center, spacing: 2) { Text("\(completedLessonsCount)").font(.system(size: 36, weight: .bold)).foregroundColor(.accentGreen); Text("Completed").font(.caption).foregroundColor(.secondary) }.frame(maxWidth: .infinity) }
                            ).frame(maxWidth: .infinity)
                        }
                        .padding(.horizontal)
                        
                        // Progress & Feedback
                        StudentDashboardCard(title: "Your Progress", systemIcon: "book.fill", accentColor: .primaryBlue, content: { StudentProgressContent(progress: progress) }).padding(.horizontal)
                        
                        NavigationLink(destination: StudentFeedbackListView(studentID: authManager.user?.id ?? "")) {
                            StudentDashboardCard(title: "Latest Feedback", systemIcon: "note.text", accentColor: .orange, content: { StudentFeedbackContent(feedback: latestFeedback) })
                        }.buttonStyle(.plain).padding(.horizontal)
                        
                        if paymentDue { Button { activeSheet = .paymentHistory } label: { PaymentDueCard() }.buttonStyle(.plain).padding(.horizontal) }
                        
                        // --- QUICK ACTIONS ---
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Quick Actions").font(.headline).padding(.horizontal)
                            
                            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 15) {
                                StudentQuickActionButton(title: "Log Practice", icon: "timer", color: .accentGreen, action: { activeSheet = .logPractice })
                                StudentQuickActionButton(title: "Notes", icon: "note.text", color: .pink, action: { activeSheet = .notes })
                                StudentQuickActionButton(title: "Contacts", icon: "phone.circle.fill", color: .blue, action: { activeSheet = .contacts })
                                StudentQuickActionButton(title: "Lesson Stats", icon: "chart.bar.fill", color: .primaryBlue, action: { activeSheet = .lessonStats })
                                StudentQuickActionButton(title: "Payment History", icon: "creditcard.fill", color: .orange, action: { activeSheet = .paymentHistory })
                                StudentQuickActionButton(title: "My Instructors", icon: "person.2.fill", color: .purple, action: { activeSheet = .myInstructors })
                                StudentQuickActionButton(title: "Find Instructor", icon: "magnifyingglass.circle.fill", color: .teal, action: { activeSheet = .findInstructor })
                            }
                            .padding(.horizontal)
                        }
                        .padding(.top, 5).padding(.bottom, 20)
                    }
                    Spacer()
                }
            }
            .navigationTitle("Dashboard").navigationBarHidden(true)
            .task {
                guard let studentID = authManager.user?.id else { isLoading = false; return }
                chatManager.listenForConversations(for: studentID)
                notificationManager.listenForNotifications(for: studentID)
                await fetchData()
            }
            .refreshable { await fetchData() }
            .sheet(item: $activeSheet) { item in
                switch item {
                case .lessonStats: if let studentID = authManager.user?.id { StudentLessonStatsView(studentID: studentID) }
                case .myInstructors: MyInstructorsView()
                case .paymentHistory: StudentPaymentHistoryView()
                case .findInstructor: InstructorDirectoryView()
                case .logPractice: StudentLogPracticeView(onSave: { Task { await fetchData() } })
                case .contacts: ContactsView()
                case .notes: NotesListView() // <--- USES GENERIC VIEW
                }
            }
        }
    }
    
    func fetchData() async {
        guard let studentID = authManager.user?.id else { isLoading = false; return }
        isLoading = true
        do {
            let data = try await dataService.fetchStudentDashboardData(for: studentID)
            self.upcomingLesson = data.upcomingLesson
            self.progress = data.progress
            self.latestFeedback = data.latestFeedback
            self.paymentDue = data.paymentDue
            self.completedLessonsCount = data.completedLessonsCount
            if let lesson = self.upcomingLesson { notificationManager.scheduleLessonReminders(lesson: lesson) }
        } catch { print("Failed: \(error)") }
        isLoading = false
    }
}

// ... (Subviews and components assumed unchanged)
struct StudentDashboardCard<Content: View>: View {
    let title: String; let systemIcon: String; var accentColor: Color = .primaryBlue; var fixedHeight: CGFloat? = nil; var backgroundColor: Color? = nil; @ViewBuilder let content: Content
    var body: some View { VStack(alignment: .leading, spacing: 10) { HStack { Label(title, systemImage: systemIcon).font(.subheadline).bold().foregroundColor(accentColor); Spacer() }; Divider().opacity(0.5); content.frame(maxWidth: .infinity, alignment: .leading); if fixedHeight != nil { Spacer(minLength: 0) } }.padding(15).frame(height: fixedHeight).background(backgroundColor ?? Color(.systemBackground)).cornerRadius(15).shadow(color: Color.textDark.opacity(0.05), radius: 8, x: 0, y: 4) }
}
struct StudentQuickActionButton: View {
    let title: String; let icon: String; let color: Color; let action: () -> Void
    var body: some View { Button(action: action) { VStack(spacing: 5) { Image(systemName: icon).font(.title2); Text(title).font(.caption).bold().lineLimit(1) }.frame(maxWidth: .infinity).padding(.vertical, 15).background(color.opacity(0.15)).foregroundColor(color).cornerRadius(12) } }
}
struct StudentProgressContent: View { let progress: Double; var body: some View { HStack { CircularProgressView(progress: progress, color: .primaryBlue, size: 80).padding(.trailing, 20); VStack(alignment: .leading) { Text("\(Int(progress * 100))%").font(.largeTitle).bold().foregroundColor(.primaryBlue); Text("Overall Mastery").font(.headline); Text("As graded by your instructor").font(.caption).foregroundColor(.textLight) }; Spacer() } } }
struct StudentFeedbackContent: View { let feedback: String; var body: some View { VStack(alignment: .leading) { if feedback.isEmpty { Text("No feedback notes yet.").font(.body).foregroundColor(.textLight) } else { Text(feedback).font(.body).lineLimit(3).foregroundColor(.primary); HStack { Spacer(); Text("View All History").font(.caption).bold().foregroundColor(.orange) } } } } }
struct PaymentDueCard: View { var body: some View { HStack { Image(systemName: "exclamationmark.triangle.fill").foregroundColor(.warningRed); VStack(alignment: .leading) { Text("Payment Pending").font(.headline).foregroundColor(.warningRed); Text("Check 'Payment History'").font(.subheadline) }; Spacer() }.padding(15).background(Color.warningRed.opacity(0.1)).cornerRadius(15).overlay(RoundedRectangle(cornerRadius: 15).stroke(Color.warningRed, lineWidth: 1)) } }
