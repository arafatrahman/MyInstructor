// File: arafatrahman/myinstructor/MyInstructor-main/MyInstructor/Features/UserManagement/StudentProfileView.swift
// --- UPDATED: Full code with Error Handling for Permissions ---

import SwiftUI

struct StudentProfileView: View {
    let student: Student
    
    @EnvironmentObject var authManager: AuthManager
    @EnvironmentObject var communityManager: CommunityManager
    @EnvironmentObject var dataService: DataService
    @Environment(\.dismiss) var dismiss
    
    @State private var studentAsAppUser: AppUser? = nil
    @State private var lessonHistory: [Lesson] = []
    @State private var payments: [Payment] = []
    
    // --- New Data State ---
    @State private var studentNotes: [StudentNote] = []
    @State private var currentProgress: Double = 0.0
    
    // Alert states
    @State private var isShowingRemoveAlert = false
    @State private var isShowingBlockAlert = false
    @State private var isShowingDeleteAlert = false
    @State private var showErrorAlert = false
    @State private var errorMessage = ""
    
    // Sheet states
    @State private var isShowingEditSheet = false
    @State private var isShowingNoteSheet = false
    @State private var isShowingProgressSheet = false
    
    // Input states
    @State private var newNoteText = ""
    @State private var newProgressValue: Double = 0.0
    
    var isOffline: Bool { return student.isOffline }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                ProfileHeaderView(
                    student: student,
                    studentAsAppUser: studentAsAppUser,
                    onAddNote: {
                        newNoteText = ""
                        isShowingNoteSheet = true
                    },
                    onUpdateProgress: {
                        newProgressValue = currentProgress
                        isShowingProgressSheet = true
                    }
                )
                .padding(.horizontal).padding(.top, 16)
                
                ProgressCard(overallProgress: currentProgress)
                    .padding(.horizontal)
                
                NotesCard(notes: studentNotes)
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
                        Button { isShowingEditSheet = true } label: { Label("Edit Profile", systemImage: "pencil") }
                        Button(role: .destructive) { isShowingDeleteAlert = true } label: { Label("Delete Student", systemImage: "trash") }
                    } else {
                        Button("Remove Student", role: .destructive) { isShowingRemoveAlert = true }
                        Button("Block Student", role: .destructive) { isShowingBlockAlert = true }
                    }
                } label: { Image(systemName: "ellipsis.circle") }
            }
        }
        .background(Color(.systemGroupedBackground).ignoresSafeArea())
        .task { await fetchData() }
        
        // --- SHEETS ---
        .sheet(isPresented: $isShowingNoteSheet) {
            NavigationView {
                VStack {
                    TextEditor(text: $newNoteText)
                        .padding().background(Color(.secondarySystemBackground)).cornerRadius(10).padding()
                    Spacer()
                }
                .navigationTitle("Add Note")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarLeading) { Button("Cancel") { isShowingNoteSheet = false } }
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("Save") { Task { await saveNote() } }
                        .disabled(newNoteText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                }
            }
            .presentationDetents([.medium])
        }
        
        .sheet(isPresented: $isShowingProgressSheet) {
            NavigationView {
                VStack(spacing: 30) {
                    CircularProgressView(progress: newProgressValue, color: .primaryBlue, size: 120).padding(.top, 20)
                    VStack {
                        Text("\(Int(newProgressValue * 100))%").font(.largeTitle).bold()
                        Text("Mastery Level").foregroundColor(.secondary)
                    }
                    Slider(value: $newProgressValue, in: 0.0...1.0, step: 0.05).tint(.primaryBlue).padding(.horizontal, 40)
                    Spacer()
                }
                .navigationTitle("Update Progress")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarLeading) { Button("Cancel") { isShowingProgressSheet = false } }
                    ToolbarItem(placement: .navigationBarTrailing) { Button("Update") { Task { await saveProgress() } } }
                }
            }
            .presentationDetents([.medium])
        }
        
        .sheet(isPresented: $isShowingEditSheet) {
            let offlineStudent = OfflineStudent(id: student.id, instructorID: authManager.user?.id ?? "", name: student.name, phone: student.phone, email: student.email, address: student.address)
            OfflineStudentFormView(studentToEdit: offlineStudent, onStudentAdded: { dismiss() })
        }
        
        // --- ALERTS ---
        .alert("Error", isPresented: $showErrorAlert) { Button("OK", role: .cancel) { } } message: { Text(errorMessage) }
        .alert("Remove Student?", isPresented: $isShowingRemoveAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Remove", role: .destructive) { Task { await removeStudent() } }
        }
        .alert("Delete Student?", isPresented: $isShowingDeleteAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) { Task { await deleteOfflineStudent() } }
        }
    }
    
    // MARK: - Logic
    func fetchData() async {
        guard let instructorID = authManager.user?.id, let studentID = student.id else { return }
        if !isOffline && studentAsAppUser == nil { self.studentAsAppUser = try? await dataService.fetchUser(withId: studentID) }
        
        if let data = try? await communityManager.fetchInstructorStudentData(instructorID: instructorID, studentID: studentID, isOffline: isOffline) {
            self.currentProgress = data.progress ?? 0.0
            self.studentNotes = data.notes ?? []
        } else {
            self.currentProgress = student.averageProgress
        }
    }
    
    func saveNote() async {
        guard let instructorID = authManager.user?.id, let studentID = student.id else { return }
        let text = newNoteText.trimmingCharacters(in: .whitespacesAndNewlines)
        
        do {
            try await communityManager.addStudentNote(instructorID: instructorID, studentID: studentID, noteContent: text, isOffline: isOffline)
            isShowingNoteSheet = false
            await fetchData()
        } catch {
            self.errorMessage = "Error saving note: \(error.localizedDescription). Check your Firestore Permissions."
            self.showErrorAlert = true
        }
    }
    
    func saveProgress() async {
        guard let instructorID = authManager.user?.id, let studentID = student.id else { return }
        
        do {
            try await communityManager.updateStudentProgress(instructorID: instructorID, studentID: studentID, newProgress: newProgressValue, isOffline: isOffline)
            self.currentProgress = newProgressValue
            isShowingProgressSheet = false
        } catch {
            self.errorMessage = "Error updating progress: \(error.localizedDescription). Check your Firestore Permissions."
            self.showErrorAlert = true
        }
    }
    
    func removeStudent() async {
        guard let instructorID = authManager.user?.id, let studentID = student.id else { return }
        try? await communityManager.removeStudent(studentID: studentID, instructorID: instructorID)
        dismiss()
    }
    
    func deleteOfflineStudent() async {
        guard let studentID = student.id else { return }
        try? await communityManager.deleteOfflineStudent(studentID: studentID)
        dismiss()
    }
}

// MARK: - Subviews
struct ProfileHeaderView: View {
    let student: Student
    let studentAsAppUser: AppUser?
    let onAddNote: () -> Void
    let onUpdateProgress: () -> Void
    
    var body: some View {
        VStack(spacing: 15) {
            HStack(alignment: .top) {
                AsyncImage(url: URL(string: student.photoURL ?? "")) { phase in
                    if let image = phase.image { image.resizable().scaledToFill() }
                    else { Image(systemName: "person.crop.circle.fill").resizable().foregroundColor(.primaryBlue) }
                }
                .frame(width: 70, height: 70).background(Color.secondaryGray).clipShape(Circle())
                
                VStack(alignment: .leading) {
                    Text(student.name).font(.title2).bold()
                    Text(student.email).font(.subheadline).foregroundColor(.textLight)
                }
                Spacer()
                
                HStack(spacing: 15) {
                    if let phone = student.phone, !phone.isEmpty {
                        Button { if let url = URL(string: "tel:\(phone.filter("0123456789+".contains))") { UIApplication.shared.open(url) } } label: { Image(systemName: "phone.circle.fill").foregroundColor(.accentGreen).font(.title) }
                    } else { Image(systemName: "phone.circle.fill").foregroundColor(.gray).font(.title) }
                    
                    if let appUser = studentAsAppUser {
                        NavigationLink(destination: ChatLoadingView(otherUser: appUser)) { Image(systemName: "message.circle.fill").foregroundColor(.primaryBlue).font(.title) }
                    } else { Image(systemName: "message.circle.fill").foregroundColor(.gray).font(.title) }
                }
            }
            HStack {
                QuickActionButton(title: "Add Note", icon: "note.text.badge.plus", color: .orange, action: onAddNote)
                QuickActionButton(title: "Update Progress", icon: "arrow.up.circle.fill", color: .accentGreen, action: onUpdateProgress)
            }
        }
        .padding().background(Color(.systemBackground)).cornerRadius(16).shadow(color: Color.black.opacity(0.08), radius: 4, y: 2)
    }
}

struct NotesCard: View {
    let notes: [StudentNote]
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("INSTRUCTOR NOTES").font(.system(size: 13, weight: .bold)).foregroundColor(.secondary).padding([.horizontal, .top], 16).padding(.bottom, 8)
            Divider().padding(.horizontal, 16)
            
            if notes.isEmpty {
                Text("No notes added yet.").font(.subheadline).foregroundColor(.textLight).padding(16)
            } else {
                VStack(alignment: .leading, spacing: 12) {
                    ForEach(notes.sorted(by: { $0.timestamp > $1.timestamp })) { note in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(note.content).font(.body).foregroundColor(.textDark)
                            Text(note.timestamp.formatted(date: .abbreviated, time: .shortened)).font(.caption).foregroundColor(.textLight)
                        }
                        .padding(.vertical, 4)
                        if note.id != notes.last?.id { Divider() }
                    }
                }.padding(16)
            }
        }
        .background(Color(.systemBackground)).cornerRadius(16).shadow(color: Color.black.opacity(0.08), radius: 4, y: 2)
    }
}

private struct ProgressCard: View {
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
                        Text("Based on instructor updates").font(.subheadline).foregroundColor(.textLight)
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
                if lessons.isEmpty { Text("No lesson history found.").font(.system(size: 15)).foregroundColor(.secondary).padding(.vertical, 8) }
                else { ForEach(lessons) { lesson in Text(lesson.topic) } }
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
                if payments.isEmpty { Text("No payment history found.").font(.system(size: 15)).foregroundColor(.secondary).padding(.vertical, 8) }
                else { ForEach(payments) { payment in Text("£\(payment.amount)") } }
            }.padding(16)
        }.background(Color(.systemBackground)).cornerRadius(16).shadow(color: Color.black.opacity(0.08), radius: 4, y: 2)
    }
}

