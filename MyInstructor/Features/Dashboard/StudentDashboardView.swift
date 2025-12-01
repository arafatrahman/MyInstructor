// File: arafatrahman/myinstructor/MyInstructor-main/MyInstructor/Features/Dashboard/StudentDashboardView.swift
// --- UPDATED: Added "My Instructors", "Payment History", and "Find Instructor" quick actions ---

import SwiftUI
import FirebaseFirestore // Added for Payment History fetching

// 1. Updated Sheet Enum
enum StudentDashboardSheet: Identifiable {
    case lessonStats
    case myInstructors
    case paymentHistory
    case findInstructor
    
    var id: Int { self.hashValue }
}

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
    @State private var completedLessonsCount: Int = 0
    @State private var isLoading = true
    
    // 2. State for active sheet
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
                        // --- EXISTING CARDS ---
                        
                        // Top Row
                        HStack(spacing: 15) {
                            if let lesson = upcomingLesson {
                                NavigationLink(destination: LessonDetailsView(lesson: lesson)) {
                                    StudentDashboardCard(
                                        title: "Next Lesson",
                                        systemIcon: "calendar.badge.clock",
                                        accentColor: .primaryBlue,
                                        fixedHeight: 150,
                                        backgroundColor: Color.primaryBlue.opacity(0.1),
                                        content: {
                                            VStack(alignment: .leading, spacing: 4) {
                                                Text(lesson.topic)
                                                    .font(.headline)
                                                    .lineLimit(1)
                                                    .foregroundColor(.primary)
                                                Text(lesson.startTime, style: .date)
                                                    .font(.caption)
                                                    .foregroundColor(.secondary)
                                                Text(lesson.startTime, style: .time)
                                                    .font(.caption)
                                                    .foregroundColor(.secondary)
                                            }
                                        }
                                    )
                                }
                                .buttonStyle(.plain)
                                .frame(maxWidth: .infinity)
                            } else {
                                StudentDashboardCard(
                                    title: "Next Lesson",
                                    systemIcon: "calendar.badge.clock",
                                    accentColor: .primaryBlue,
                                    fixedHeight: 150,
                                    backgroundColor: Color.primaryBlue.opacity(0.1),
                                    content: {
                                        Text("No upcoming lessons.")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                )
                                .frame(maxWidth: .infinity)
                            }
                            
                            StudentDashboardCard(
                                title: "Lessons Taken",
                                systemIcon: "checkmark.circle.fill",
                                accentColor: .accentGreen,
                                fixedHeight: 150,
                                backgroundColor: Color.accentGreen.opacity(0.1),
                                content: {
                                    VStack(alignment: .center, spacing: 2) {
                                        Text("\(completedLessonsCount)")
                                            .font(.system(size: 36, weight: .bold))
                                            .foregroundColor(.accentGreen)
                                        Text("Completed")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                    .frame(maxWidth: .infinity)
                                }
                            )
                            .frame(maxWidth: .infinity)
                        }
                        .padding(.horizontal)
                        
                        // Progress
                        StudentDashboardCard(title: "Your Progress", systemIcon: "book.fill", accentColor: .primaryBlue, content: {
                            StudentProgressContent(progress: progress)
                        }).padding(.horizontal)
                        
                        // Feedback
                        NavigationLink(destination: StudentFeedbackListView(studentID: authManager.user?.id ?? "")) {
                            StudentDashboardCard(title: "Latest Feedback", systemIcon: "note.text", accentColor: .orange, content: {
                                StudentFeedbackContent(feedback: latestFeedback)
                            })
                        }
                        .buttonStyle(.plain)
                        .padding(.horizontal)
                        
                        // Payment Alert
                        if paymentDue {
                            Button { activeSheet = .paymentHistory } label: {
                                PaymentDueCard()
                            }
                            .buttonStyle(.plain)
                            .padding(.horizontal)
                        }
                        
                        // --- 3. QUICK ACTIONS SECTION ---
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Quick Actions")
                                .font(.headline)
                                .padding(.horizontal)
                            
                            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 15) {
                                // 1. Track Lessons
                                StudentQuickActionButton(
                                    title: "Lesson Stats",
                                    icon: "chart.bar.fill",
                                    color: .primaryBlue,
                                    action: { activeSheet = .lessonStats }
                                )
                                
                                // 2. My Instructors
                                StudentQuickActionButton(
                                    title: "My Instructors",
                                    icon: "person.2.fill",
                                    color: .orange,
                                    action: { activeSheet = .myInstructors }
                                )
                                
                                // 3. Payment History
                                StudentQuickActionButton(
                                    title: "Payment History",
                                    icon: "creditcard.fill",
                                    color: .accentGreen,
                                    action: { activeSheet = .paymentHistory }
                                )
                                
                                // 4. Find Instructor
                                StudentQuickActionButton(
                                    title: "Find Instructor",
                                    icon: "magnifyingglass.circle.fill",
                                    color: .purple,
                                    action: { activeSheet = .findInstructor }
                                )
                            }
                            .padding(.horizontal)
                        }
                        .padding(.top, 5)
                        // -----------------------------
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
                chatManager.listenForConversations(for: studentID)
                notificationManager.listenForNotifications(for: studentID)
                
                await fetchData()
            }
            .refreshable { await fetchData() }
            // 4. Sheet Handler
            .sheet(item: $activeSheet) { item in
                switch item {
                case .lessonStats:
                    if let studentID = authManager.user?.id {
                        StudentLessonStatsView(studentID: studentID)
                    }
                case .myInstructors:
                    MyInstructorsView() // Reusing existing view
                case .paymentHistory:
                    StudentPaymentHistoryView() // New View defined below
                case .findInstructor:
                    InstructorDirectoryView() // Reusing existing view
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
            
            if let lesson = self.upcomingLesson {
                notificationManager.scheduleLessonReminders(lesson: lesson)
            }
        } catch { print("Failed: \(error)") }
        isLoading = false
    }
}

// MARK: - Components

struct StudentDashboardCard<Content: View>: View {
    let title: String
    let systemIcon: String
    var accentColor: Color = .primaryBlue
    var fixedHeight: CGFloat? = nil
    var backgroundColor: Color? = nil
    @ViewBuilder let content: Content
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label(title, systemImage: systemIcon)
                    .font(.subheadline).bold()
                    .foregroundColor(accentColor)
                Spacer()
            }
            Divider().opacity(0.5)
            content
                .frame(maxWidth: .infinity, alignment: .leading)
            
            if fixedHeight != nil { Spacer(minLength: 0) }
        }
        .padding(15)
        .frame(height: fixedHeight)
        .background(backgroundColor ?? Color(.systemBackground))
        .cornerRadius(15)
        .shadow(color: Color.textDark.opacity(0.05), radius: 8, x: 0, y: 4)
    }
}

// 5. Unique Quick Action Button for Student
struct StudentQuickActionButton: View {
    let title: String
    let icon: String
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 5) {
                Image(systemName: icon)
                    .font(.title2)
                Text(title)
                    .font(.caption).bold()
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 15)
            .background(color.opacity(0.15))
            .foregroundColor(color)
            .cornerRadius(12)
        }
    }
}

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
            VStack(alignment: .leading) { Text("Payment Pending").font(.headline).foregroundColor(.warningRed); Text("Tap to view details").font(.subheadline) }
            Spacer()
        }.padding(15).background(Color.warningRed.opacity(0.1)).cornerRadius(15).overlay(RoundedRectangle(cornerRadius: 15).stroke(Color.warningRed, lineWidth: 1))
    }
}

// --- NEW: Student Payment History View ---
struct StudentPaymentHistoryView: View {
    @EnvironmentObject var authManager: AuthManager
    @Environment(\.dismiss) var dismiss
    
    @State private var payments: [Payment] = []
    @State private var isLoading = true
    
    var body: some View {
        NavigationView {
            VStack {
                if isLoading {
                    ProgressView("Loading Payments...")
                } else if payments.isEmpty {
                    EmptyStateView(icon: "creditcard", message: "No payment history found.")
                } else {
                    List {
                        ForEach(payments) { payment in
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(payment.date.formatted(date: .abbreviated, time: .omitted))
                                        .font(.headline)
                                    Text(payment.isPaid ? "Paid via \(payment.paymentMethod?.rawValue ?? "Unknown")" : "Pending Payment")
                                        .font(.caption)
                                        .foregroundColor(payment.isPaid ? .secondary : .warningRed)
                                }
                                Spacer()
                                Text(payment.amount, format: .currency(code: "GBP"))
                                    .font(.headline)
                                    .foregroundColor(payment.isPaid ? .accentGreen : .warningRed)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Payment History")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") { dismiss() }
                }
            }
            .task {
                guard let studentID = authManager.user?.id else { return }
                do {
                    let snapshot = try await Firestore.firestore().collection("payments")
                        .whereField("studentID", isEqualTo: studentID)
                        .order(by: "date", descending: true)
                        .getDocuments()
                    self.payments = snapshot.documents.compactMap { try? $0.data(as: Payment.self) }
                } catch {
                    print("Error fetching payments: \(error)")
                }
                isLoading = false
            }
        }
    }
}
