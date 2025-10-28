import SwiftUI

// Flow Item 12: Student Profile (Instructor View)
struct StudentProfileView: View {
    let student: Student
    
    // Inject managers via environment
    @EnvironmentObject var lessonManager: LessonManager
    @EnvironmentObject var paymentManager: PaymentManager
    
    @State private var selectedTab: ProfileTab = .progress
    
    // Removed mock skills data
    @State private var skills: [String: Double] = [:]
    
    // Computed property to access and filter lessons
    // This will now be empty unless the manager is populated with real data
    var lessonHistory: [Lesson] {
        // TODO: This relies on a public mock array.
        // This view should *fetch* its own data.
        // lessonManager.publicMockLessons.filter { $0.studentID == student.id }
        
        // For now, return empty until a proper fetch is implemented.
        return []
    }
    
    // Computed property to access and filter payments
    // This will also be empty.
    var payments: [Payment] {
        // paymentManager.publicMockPayments.filter { $0.studentID == student.id }
        return []
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header: Photo, contact icons, "Add Note / Update Progress"
            ProfileHeaderView(student: student, onUpdateProgress: {
                // TODO: Open modal for updating skills (Flow 8 progress section logic)
                print("Updating progress for \(student.name)")
            })
            
            // Tabs: Progress | Lessons | Payments
            Picker("Profile View", selection: $selectedTab) {
                Text("Progress").tag(ProfileTab.progress)
                Text("Lessons").tag(ProfileTab.lessons)
                Text("Payments").tag(ProfileTab.payments)
            }
            .pickerStyle(.segmented)
            .padding([.horizontal, .top])
            
            Divider()
                .padding(.vertical, 8)
            
            // Tab Content
            TabView(selection: $selectedTab) {
                ProgressTabView(skills: skills, overallProgress: student.averageProgress)
                    .tag(ProfileTab.progress)
                
                LessonsTabView(lessons: lessonHistory)
                    .tag(ProfileTab.lessons)
                
                PaymentsTabView(payments: payments)
                    .tag(ProfileTab.payments)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .animation(.easeInOut, value: selectedTab)
        }
        .navigationTitle(student.name)
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await fetchData()
        }
    }
    
    func fetchData() async {
        // TODO: Implement fetching for this student's
        // skills, lessons, and payments
        print("Fetching data for student \(student.id ?? "N/A")")
        // e.g., self.skills = await progressManager.fetchSkills(for: student.id)
        // e.g., self.lessonHistory = await lessonManager.fetchLessons(forStudent: student.id)
        // e.g., self.payments = await paymentManager.fetchPayments(forStudent: student.id)
    }
}

enum ProfileTab: String {
    case progress, lessons, payments
}

// ----------------------------------------------------------------------
// MARK: - SUPPORTING VIEWS
// ----------------------------------------------------------------------
// NOTE: Supporting views (ProfileHeaderView, ProgressTabView, etc.) are assumed
// to be defined in this file's global scope or a shared file.

struct ProfileHeaderView: View {
    let student: Student
    let onUpdateProgress: () -> Void
    
    var body: some View {
        VStack(spacing: 15) {
            HStack(alignment: .top) {
                // Photo & Name
                Image(systemName: "person.crop.circle.fill")
                    .resizable()
                    .frame(width: 70, height: 70)
                    .foregroundColor(.primaryBlue)
                
                VStack(alignment: .leading) {
                    Text(student.name)
                        .font(.title2).bold()
                    Text(student.email)
                        .font(.subheadline)
                        .foregroundColor(.textLight)
                }
                Spacer()
                
                // Contact Icons
                HStack(spacing: 15) {
                    Image(systemName: "phone.circle.fill").foregroundColor(.accentGreen).font(.title)
                    Image(systemName: "message.circle.fill").foregroundColor(.primaryBlue).font(.title)
                }
            }
            
            // CTA Buttons (Assumes QuickActionButton is available)
            HStack {
                QuickActionButton(title: "Add Note", icon: "note.text.badge.plus", color: .orange, action: {})
                QuickActionButton(title: "Update Progress", icon: "arrow.up.circle.fill", color: .accentGreen, action: onUpdateProgress)
            }
        }
        .padding(.horizontal)
    }
}

// 1️⃣ Progress Tab Content
struct ProgressTabView: View {
    let skills: [String: Double]
    let overallProgress: Double
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 25) {
                // Circular Graph & Summary (Assumes CircularProgressView is available)
                HStack(spacing: 20) {
                    CircularProgressView(progress: overallProgress, color: .primaryBlue, size: 100)
                    
                    VStack(alignment: .leading) {
                        Text("\(Int(overallProgress * 100))% Overall Mastery")
                            .font(.headline)
                        Text("Progress Timeline (Graph Placeholder)")
                            .font(.subheadline)
                            .foregroundColor(.textLight)
                    }
                    Spacer()
                }
                .padding(.horizontal)
                
                // Skills list
                Text("Skill Breakdown")
                    .font(.title3).bold()
                    .padding(.horizontal)
                
                if skills.isEmpty {
                    Text("No skills tracked yet.")
                        .foregroundColor(.textLight)
                        .padding(.horizontal)
                } else {
                    ForEach(skills.keys.sorted(), id: \.self) { skill in
                        SkillProgressRow(skill: skill, progress: skills[skill]!)
                    }
                }
                
                // Instructor notes section (Placeholder)
                Text("Instructor Notes")
                    .font(.title3).bold()
                    .padding(.horizontal)
                Text("No notes added yet.") // Placeholder text
                    .padding(.horizontal)
                    .foregroundColor(.textLight)
            }
            .padding(.top)
        }
    }
}

struct SkillProgressRow: View {
    let skill: String
    let progress: Double
    
    var progressColor: Color {
        if progress > 0.75 { return .accentGreen }
        if progress > 0.5 { return .orange }
        return .warningRed
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack {
                Text(skill).font(.body)
                Spacer()
                Text("\(Int(progress * 100))%")
                    .bold()
                    .foregroundColor(progressColor)
            }
            ProgressView(value: progress)
                .tint(progressColor)
        }
        .padding(.horizontal)
    }
}

// 2️⃣ Lessons Tab Content
struct LessonsTabView: View {
    let lessons: [Lesson]
    
    var body: some View {
        List {
            Section("Lesson History") {
                if lessons.isEmpty {
                    Text("No lesson history found.")
                        .foregroundColor(.textLight)
                } else {
                    ForEach(lessons.sorted(by: { $0.startTime > $1.startTime })) { lesson in
                        VStack(alignment: .leading) {
                            Text(lesson.topic).bold()
                            HStack {
                                Text(lesson.startTime, style: .date)
                                Spacer()
                                Text(lesson.status.rawValue.capitalized)
                                    .foregroundColor(lesson.status == .completed ? .accentGreen : .primaryBlue)
                            }
                            .font(.caption)
                            .foregroundColor(.textLight)
                        }
                    }
                }
            }
        }
    }
}

// 3️⃣ Payments Tab Content
struct PaymentsTabView: View {
    let payments: [Payment]
    
    var body: some View {
        List {
            Section("Payment History") {
                if payments.isEmpty {
                    Text("No payment history found.")
                        .foregroundColor(.textLight)
                } else {
                    ForEach(payments.sorted(by: { $0.date > $1.date })) { payment in
                        HStack {
                            VStack(alignment: .leading) {
                                Text(payment.isPaid ? "Payment Received" : "Payment Pending")
                                    .font(.headline)
                                    .foregroundColor(payment.isPaid ? .accentGreen : .warningRed)
                                Text(payment.date, style: .date)
                                    .font(.caption).foregroundColor(.textLight)
                            }
                            Spacer()
                            Text("£\(payment.amount, specifier: "%.2f")")
                                .font(.title3).bold()
                        }
                    }
                }
            }
            
            Section {
                Button("View All Payments") {
                    // TODO: Navigate to main PaymentsView (Flow 13)
                    print("Navigating to PaymentsView")
                }
            }
        }
    }
}
