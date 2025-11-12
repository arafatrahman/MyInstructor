// File: arafatrahman/myinstructor/MyInstructor-main/MyInstructor/Features/UserManagement/StudentProfileView.swift
// --- UPDATED: Moved "Remove" and "Block" buttons to a toolbar menu ---

import SwiftUI

// Flow Item 12: Student Profile (Instructor View)
struct StudentProfileView: View {
    let student: Student
    
    // Inject managers via environment
    @EnvironmentObject var lessonManager: LessonManager
    @EnvironmentObject var paymentManager: PaymentManager
    @EnvironmentObject var communityManager: CommunityManager
    @EnvironmentObject var authManager: AuthManager
    @Environment(\.dismiss) var dismiss
    
    @EnvironmentObject var dataService: DataService
    @State private var studentAsAppUser: AppUser? = nil
    
    // --- State for the card data ---
    @State private var skills: [String: Double] = [:] // Mock data
    @State private var lessonHistory: [Lesson] = [] // Mock data
    @State private var payments: [Payment] = [] // Mock data
    
    @State private var isShowingRemoveAlert = false
    @State private var isShowingBlockAlert = false

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Header: Photo, contact icons, "Add Note / Update Progress"
                ProfileHeaderView(student: student, studentAsAppUser: studentAsAppUser, onUpdateProgress: {
                    print("Updating progress for \(student.name)")
                })
                .padding(.horizontal)
                .padding(.top, 16)
                
                ProgressCard(skills: skills, overallProgress: student.averageProgress)
                    .padding(.horizontal)
                
                LessonsCard(lessons: lessonHistory)
                    .padding(.horizontal)
                
                PaymentsCard(payments: payments)
                    .padding(.horizontal)
                
                Spacer(minLength: 20)
                
                // --- *** ACTION BUTTONS REMOVED FROM HERE *** ---
            }
            .padding(.bottom, 20) // Add bottom padding
        }
        .navigationTitle(student.name)
        .navigationBarTitleDisplayMode(.inline)
        // --- *** THIS IS THE NEW TOOLBAR *** ---
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Menu {
                    Button("Remove Student", role: .destructive) {
                        isShowingRemoveAlert = true
                    }
                    Button("Block Student", role: .destructive) {
                        isShowingBlockAlert = true
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        // --- *** END OF NEW TOOLBAR *** ---
        .background(Color(.systemGroupedBackground).ignoresSafeArea())
        .task {
            await fetchData()
            if studentAsAppUser == nil, let studentID = student.id {
                self.studentAsAppUser = try? await dataService.fetchUser(withId: studentID)
            }
        }
        .alert("Remove \(student.name)?", isPresented: $isShowingRemoveAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Remove", role: .destructive) {
                Task { await removeStudent() }
            }
        } message: {
            Text("This will remove the student from your active list. They will be notified and can re-apply later.")
        }
        .alert("Block \(student.name)?", isPresented: $isShowingBlockAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Block", role: .destructive) {
                Task { await blockStudent() }
            }
        } message: {
            Text("This will permanently block this student. They will be removed from your list and will not be able to send you new requests.")
        }
    }
    
    func fetchData() async {
        print("Fetching data for student \(student.id ?? "N/A")")
        // TODO: Load real data for skills, lessons, and payments
        // self.skills = ...
        // self.lessonHistory = ...
        // self.payments = ...
    }
    
    func removeStudent() async {
        guard let instructorID = authManager.user?.id, let studentID = student.id else { return }
        do {
            try await communityManager.removeStudent(studentID: studentID, instructorID: instructorID)
            dismiss()
        } catch {
            print("Failed to remove student: \(error)")
        }
    }
    
    func blockStudent() async {
        guard let instructorID = authManager.user?.id, let studentID = student.id else { return }
        do {
            try await communityManager.blockStudent(studentID: studentID, instructorID: instructorID)
            dismiss()
        } catch {
            print("Failed to block student: \(error)")
        }
    }
}

// ----------------------------------------------------------------------
// MARK: - SUPPORTING VIEWS
// ----------------------------------------------------------------------

struct ProfileHeaderView: View {
    let student: Student
    let studentAsAppUser: AppUser?
    let onUpdateProgress: () -> Void
    
    var body: some View {
        VStack(spacing: 15) {
            HStack(alignment: .top) {
                AsyncImage(url: URL(string: student.photoURL ?? "")) { phase in
                    if let image = phase.image {
                        image.resizable().scaledToFill()
                    } else {
                        Image(systemName: "person.crop.circle.fill")
                            .resizable()
                            .foregroundColor(.primaryBlue)
                    }
                }
                .frame(width: 70, height: 70)
                .background(Color.secondaryGray)
                .clipShape(Circle())
                
                VStack(alignment: .leading) {
                    Text(student.name)
                        .font(.title2).bold()
                    Text(student.email)
                        .font(.subheadline)
                        .foregroundColor(.textLight)
                }
                Spacer()
                
                HStack(spacing: 15) {
                    Image(systemName: "phone.circle.fill").foregroundColor(.accentGreen).font(.title)
                    
                    if let appUser = studentAsAppUser {
                        NavigationLink(destination: ChatLoadingView(otherUser: appUser)) {
                            Image(systemName: "message.circle.fill")
                                .foregroundColor(.primaryBlue).font(.title)
                        }
                    } else {
                        Image(systemName: "message.circle.fill")
                            .foregroundColor(.gray).font(.title)
                    }
                }
            }
            
            HStack {
                QuickActionButton(title: "Add Note", icon: "note.text.badge.plus", color: .orange, action: {})
                QuickActionButton(title: "Update Progress", icon: "arrow.up.circle.fill", color: .accentGreen, action: onUpdateProgress)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.08), radius: 4, y: 2)
    }
}

private struct ProgressCard: View {
    let skills: [String: Double]
    let overallProgress: Double
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("PROGRESS")
                .font(.system(size: 13, weight: .bold))
                .foregroundColor(.secondary)
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 8)
            Divider().padding(.horizontal, 16)

            VStack(alignment: .leading, spacing: 20) {
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
                
                Text("Skill Breakdown")
                    .font(.title3).bold()
                
                if skills.isEmpty {
                    Text("No skills tracked yet.")
                        .foregroundColor(.textLight)
                } else {
                    ForEach(skills.keys.sorted(), id: \.self) { skill in
                        SkillProgressRow(skill: skill, progress: skills[skill]!)
                    }
                }
            }
            .padding(16)
        }
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.08), radius: 4, y: 2)
    }
}

private struct LessonsCard: View {
    let lessons: [Lesson]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("LESSON HISTORY")
                .font(.system(size: 13, weight: .bold))
                .foregroundColor(.secondary)
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 8)
            Divider().padding(.horizontal, 16)

            VStack(alignment: .leading, spacing: 14) {
                if lessons.isEmpty {
                    Text("No lesson history found.")
                        .font(.system(size: 15))
                        .foregroundColor(.secondary)
                        .padding(.vertical, 8) // Add padding so card isn't empty
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
                        if lesson.id != lessons.last?.id {
                            Divider()
                        }
                    }
                }
            }
            .padding(16)
        }
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.08), radius: 4, y: 2)
    }
}

private struct PaymentsCard: View {
    let payments: [Payment]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("PAYMENT HISTORY")
                .font(.system(size: 13, weight: .bold))
                .foregroundColor(.secondary)
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 8)
            Divider().padding(.horizontal, 16)

            VStack(alignment: .leading, spacing: 14) {
                if payments.isEmpty {
                    Text("No payment history found.")
                        .font(.system(size: 15))
                        .foregroundColor(.secondary)
                        .padding(.vertical, 8)
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
                        if payment.id != payments.last?.id {
                            Divider()
                        }
                    }
                }
            }
            .padding(16)
        }
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.08), radius: 4, y: 2)
    }
}


private struct SkillProgressRow: View {
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
    }
}

// (Button Styles are unchanged)
struct DestructiveDrivingAppButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .padding(.vertical, 14)
            .frame(maxWidth: .infinity)
            .background(Color.warningRed)
            .foregroundColor(.white)
            .cornerRadius(12)
            .shadow(color: Color.warningRed.opacity(0.3), radius: configuration.isPressed ? 3 : 8, x: 0, y: configuration.isPressed ? 2 : 5)
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .opacity(configuration.isPressed ? 0.9 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

struct RemoveDestructiveDrivingAppButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .padding(.vertical, 14)
            .frame(maxWidth: .infinity)
            .background(Color.secondaryGray)
            .foregroundColor(.black)
            .cornerRadius(12)
            .shadow(color: Color.warningRed.opacity(0.3), radius: configuration.isPressed ? 3 : 8, x: 0, y: configuration.isPressed ? 2 : 5)
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .opacity(configuration.isPressed ? 0.9 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}
