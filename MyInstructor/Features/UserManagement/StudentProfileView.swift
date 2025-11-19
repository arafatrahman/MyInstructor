// File: arafatrahman/myinstructor/MyInstructor-main/MyInstructor/Features/UserManagement/StudentProfileView.swift
// --- UPDATED: Custom Toolbar for Offline Students (Edit/Delete) and logic to handle them ---

import SwiftUI

// Flow Item 12: Student Profile (Instructor View)
struct StudentProfileView: View {
    let student: Student
    
    @EnvironmentObject var lessonManager: LessonManager
    @EnvironmentObject var paymentManager: PaymentManager
    @EnvironmentObject var communityManager: CommunityManager
    @EnvironmentObject var authManager: AuthManager
    @EnvironmentObject var dataService: DataService
    @Environment(\.dismiss) var dismiss
    
    @State private var studentAsAppUser: AppUser? = nil
    
    // Data state
    @State private var skills: [String: Double] = [:]
    @State private var lessonHistory: [Lesson] = []
    @State private var payments: [Payment] = []
    
    // Alert states
    @State private var isShowingRemoveAlert = false
    @State private var isShowingBlockAlert = false
    @State private var isShowingDeleteAlert = false // For Offline
    
    // Sheet state
    @State private var isShowingEditSheet = false // For Offline Edit
    
    // Computed property to easily check type
    var isOffline: Bool {
        return student.isOffline
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Header
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
            }
            .padding(.bottom, 20)
        }
        .navigationTitle(student.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Menu {
                    if isOffline {
                        // --- *** Offline Actions *** ---
                        Button {
                            isShowingEditSheet = true
                        } label: {
                            Label("Edit Profile", systemImage: "pencil")
                        }
                        
                        Button(role: .destructive) {
                            isShowingDeleteAlert = true
                        } label: {
                            Label("Delete Student", systemImage: "trash")
                        }
                    } else {
                        // --- *** Online Actions *** ---
                        Button("Remove Student", role: .destructive) {
                            isShowingRemoveAlert = true
                        }
                        Button("Block Student", role: .destructive) {
                            isShowingBlockAlert = true
                        }
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .background(Color(.systemGroupedBackground).ignoresSafeArea())
        .task {
            await fetchData()
            // Only try to fetch AppUser if NOT offline
            if !isOffline && studentAsAppUser == nil, let studentID = student.id {
                self.studentAsAppUser = try? await dataService.fetchUser(withId: studentID)
            }
        }
        // --- ALERTS ---
        .alert("Remove \(student.name)?", isPresented: $isShowingRemoveAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Remove", role: .destructive) { Task { await removeStudent() } }
        } message: { Text("This will remove the student from your active list.") }
        
        .alert("Block \(student.name)?", isPresented: $isShowingBlockAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Block", role: .destructive) { Task { await blockStudent() } }
        } message: { Text("This will permanently block this student.") }
        
        .alert("Delete \(student.name)?", isPresented: $isShowingDeleteAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) { Task { await deleteOfflineStudent() } }
        } message: { Text("This will permanently delete this offline student record. This cannot be undone.") }
        
        // --- EDIT SHEET (Offline) ---
        .sheet(isPresented: $isShowingEditSheet) {
            // Create an OfflineStudent object from the current Student data to pass to the form
            let offlineStudent = OfflineStudent(
                id: student.id,
                instructorID: authManager.user?.id ?? "",
                name: student.name,
                phone: student.phone,
                email: student.email,
                address: student.address
            )
            
            OfflineStudentFormView(studentToEdit: offlineStudent, onStudentAdded: {
                // Refresh view logic (e.g. re-fetch data or dismiss)
                // For simplicity, we just dismiss the profile view to refresh the list
                dismiss()
            })
        }
    }
    
    func fetchData() async {
        // Load lessons, payments, etc using student.id
    }
    
    func removeStudent() async {
        guard let instructorID = authManager.user?.id, let studentID = student.id else { return }
        try? await communityManager.removeStudent(studentID: studentID, instructorID: instructorID)
        dismiss()
    }
    
    func blockStudent() async {
        guard let instructorID = authManager.user?.id, let studentID = student.id else { return }
        try? await communityManager.blockStudent(studentID: studentID, instructorID: instructorID)
        dismiss()
    }
    
    // --- *** NEW FUNCTION *** ---
    func deleteOfflineStudent() async {
        guard let studentID = student.id else { return }
        try? await communityManager.deleteOfflineStudent(studentID: studentID)
        dismiss()
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
                    if let image = phase.image { image.resizable().scaledToFill() }
                    else {
                        Image(systemName: "person.crop.circle.fill")
                            .resizable().foregroundColor(.primaryBlue)
                    }
                }
                .frame(width: 70, height: 70)
                .background(Color.secondaryGray).clipShape(Circle())
                
                VStack(alignment: .leading) {
                    Text(student.name).font(.title2).bold()
                    Text(student.email).font(.subheadline).foregroundColor(.textLight)
                }
                Spacer()
                
                HStack(spacing: 15) {
                    // Phone Button
                    if let phone = student.phone, !phone.isEmpty {
                        Button {
                            if let url = URL(string: "tel:\(phone.filter("0123456789+".contains))") {
                                UIApplication.shared.open(url)
                            }
                        } label: {
                            Image(systemName: "phone.circle.fill").foregroundColor(.accentGreen).font(.title)
                        }
                    } else {
                         Image(systemName: "phone.circle.fill").foregroundColor(.gray).font(.title)
                    }
                    
                    // Chat Button (Only enabled if online user exists)
                    if let appUser = studentAsAppUser {
                        NavigationLink(destination: ChatLoadingView(otherUser: appUser)) {
                            Image(systemName: "message.circle.fill").foregroundColor(.primaryBlue).font(.title)
                        }
                    } else {
                        Image(systemName: "message.circle.fill").foregroundColor(.gray).font(.title)
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

// (Rest of the file: ProgressCard, LessonsCard, PaymentsCard, etc. remain unchanged)
private struct ProgressCard: View {
    let skills: [String: Double]
    let overallProgress: Double
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("PROGRESS").font(.system(size: 13, weight: .bold)).foregroundColor(.secondary).padding([.horizontal, .top], 16).padding(.bottom, 8)
            Divider().padding(.horizontal, 16)
            VStack(alignment: .leading, spacing: 20) {
                HStack(spacing: 20) {
                    CircularProgressView(progress: overallProgress, color: .primaryBlue, size: 100)
                    VStack(alignment: .leading) {
                        Text("\(Int(overallProgress * 100))% Overall Mastery").font(.headline)
                        Text("Progress Timeline").font(.subheadline).foregroundColor(.textLight)
                    }
                    Spacer()
                }
            }.padding(16)
        }.background(Color(.systemBackground)).cornerRadius(16).shadow(color: Color.black.opacity(0.08), radius: 4, y: 2)
    }
}

private struct LessonsCard: View {
    let lessons: [Lesson]
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("LESSON HISTORY").font(.system(size: 13, weight: .bold)).foregroundColor(.secondary).padding([.horizontal, .top], 16).padding(.bottom, 8)
            Divider().padding(.horizontal, 16)
            VStack(alignment: .leading, spacing: 14) {
                if lessons.isEmpty {
                    Text("No lesson history found.").font(.system(size: 15)).foregroundColor(.secondary).padding(.vertical, 8)
                } else {
                    ForEach(lessons) { lesson in Text(lesson.topic) }
                }
            }.padding(16)
        }.background(Color(.systemBackground)).cornerRadius(16).shadow(color: Color.black.opacity(0.08), radius: 4, y: 2)
    }
}

private struct PaymentsCard: View {
    let payments: [Payment]
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("PAYMENT HISTORY").font(.system(size: 13, weight: .bold)).foregroundColor(.secondary).padding([.horizontal, .top], 16).padding(.bottom, 8)
            Divider().padding(.horizontal, 16)
            VStack(alignment: .leading, spacing: 14) {
                if payments.isEmpty {
                    Text("No payment history found.").font(.system(size: 15)).foregroundColor(.secondary).padding(.vertical, 8)
                } else {
                    ForEach(payments) { payment in Text("£\(payment.amount)") }
                }
            }.padding(16)
        }.background(Color(.systemBackground)).cornerRadius(16).shadow(color: Color.black.opacity(0.08), radius: 4, y: 2)
    }
}
