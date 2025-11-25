// File: arafatrahman/myinstructor/MyInstructor-main/MyInstructor/Features/UserManagement/StudentProfileView.swift
// --- UPDATED: Redesigned "Add/Edit Note" popup for a modern look ---

import SwiftUI

struct StudentProfileView: View {
    let student: Student
    
    @EnvironmentObject var lessonManager: LessonManager
    @EnvironmentObject var paymentManager: PaymentManager
    @EnvironmentObject var communityManager: CommunityManager
    @EnvironmentObject var authManager: AuthManager
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
    
    // Error Alert for permissions
    @State private var isShowingErrorAlert = false
    @State private var errorMessage = ""
    
    // Sheet states
    @State private var isShowingEditSheet = false
    @State private var isShowingNoteSheet = false
    @State private var isShowingProgressSheet = false
    
    // Input states for Notes
    @State private var noteText = ""
    @State private var editingNote: StudentNote? = nil // Tracks if we are editing an existing note
    
    @State private var newProgressValue: Double = 0.0
    
    var isOffline: Bool {
        return student.isOffline
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Header with Action Buttons
                ProfileHeaderView(
                    student: student,
                    studentAsAppUser: studentAsAppUser,
                    onAddNote: {
                        editingNote = nil
                        noteText = ""
                        isShowingNoteSheet = true
                    },
                    onUpdateProgress: {
                        newProgressValue = currentProgress
                        isShowingProgressSheet = true
                    }
                )
                .padding(.horizontal)
                .padding(.top, 16)
                
                ProgressCard(overallProgress: currentProgress)
                    .padding(.horizontal)
                
                // Notes Card
                NotesCard(
                    notes: studentNotes,
                    onEdit: { note in
                        editingNote = note
                        noteText = note.content
                        isShowingNoteSheet = true
                    },
                    onDelete: { note in
                        Task { await deleteNote(note) }
                    }
                )
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
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .background(Color(.systemGroupedBackground).ignoresSafeArea())
        .task {
            await fetchData()
        }
        
        // --- SHEETS ---
        
        // 1. Modern Add/Edit Note Sheet (UPDATED)
        .sheet(isPresented: $isShowingNoteSheet) {
            VStack(spacing: 20) {
                // Custom Handle
                Capsule()
                    .fill(Color.secondary.opacity(0.3))
                    .frame(width: 40, height: 5)
                    .padding(.top, 12)
                
                // Header
                HStack {
                    Text(editingNote == nil ? "New Note" : "Edit Note")
                        .font(.title2).bold()
                        .foregroundColor(.primary)
                    
                    Spacer()
                    
                    Button {
                        isShowingNoteSheet = false
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title2)
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.horizontal, 20)
                
                // Note Input Area
                ZStack(alignment: .topLeading) {
                    if noteText.isEmpty {
                        Text("Write your observations, feedback, or reminders here...")
                            .foregroundColor(Color(.placeholderText))
                            .padding(.horizontal, 16)
                            .padding(.vertical, 16)
                            .allowsHitTesting(false)
                    }
                    
                    TextEditor(text: $noteText)
                        .scrollContentBackground(.hidden) // Removes default gray background
                        .padding(10)
                        .background(Color(.secondarySystemBackground))
                        .cornerRadius(16)
                }
                .padding(.horizontal, 20)
                
                // Save Button
                Button {
                    Task { await saveOrUpdateNote() }
                } label: {
                    HStack {
                        if noteText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            Text("Save Note")
                        } else {
                            Image(systemName: "checkmark.circle.fill")
                            Text("Save Note")
                        }
                    }
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(
                        noteText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                        ? Color.secondary.opacity(0.3)
                        : Color.primaryBlue
                    )
                    .cornerRadius(16)
                }
                .disabled(noteText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                .padding(.horizontal, 20)
                .padding(.bottom, 10)
            }
            .background(Color(.systemBackground))
            .presentationDetents([.medium, .large]) // Allow expansion
            .presentationDragIndicator(.hidden) // We implemented a custom one
        }
        
        // 2. Update Progress Sheet
        .sheet(isPresented: $isShowingProgressSheet) {
            NavigationView {
                VStack(spacing: 30) {
                    CircularProgressView(progress: newProgressValue, color: .primaryBlue, size: 120)
                        .padding(.top, 20)
                    
                    VStack {
                        Text("\(Int(newProgressValue * 100))%")
                            .font(.largeTitle).bold()
                        Text("Mastery Level")
                            .foregroundColor(.secondary)
                    }
                    
                    Slider(value: $newProgressValue, in: 0.0...1.0, step: 0.05)
                        .tint(.primaryBlue)
                        .padding(.horizontal, 40)
                    
                    Spacer()
                }
                .navigationTitle("Update Progress")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarLeading) { Button("Cancel") { isShowingProgressSheet = false } }
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("Update") {
                            Task { await saveProgress() }
                        }
                    }
                }
            }
            .presentationDetents([.medium])
        }
        
        // 3. Edit Profile Sheet (Offline Only)
        .sheet(isPresented: $isShowingEditSheet) {
            let offlineStudent = OfflineStudent(
                id: student.id,
                instructorID: authManager.user?.id ?? "",
                name: student.name,
                phone: student.phone,
                email: student.email,
                address: student.address
            )
            OfflineStudentFormView(studentToEdit: offlineStudent, onStudentAdded: { dismiss() })
        }
        
        // --- ALERTS ---
        .alert("Error", isPresented: $isShowingErrorAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(errorMessage)
        }
        
        .alert("Remove Student?", isPresented: $isShowingRemoveAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Remove", role: .destructive) { Task { await removeStudent() } }
        }
        .alert("Block Student?", isPresented: $isShowingBlockAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Block", role: .destructive) { Task { await blockStudent() } }
        }
        .alert("Delete Student?", isPresented: $isShowingDeleteAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) { Task { await deleteOfflineStudent() } }
        }
    }
    
    // MARK: - Logic Functions
    
    func fetchData() async {
        guard let instructorID = authManager.user?.id, let studentID = student.id else { return }
        
        if !isOffline && studentAsAppUser == nil {
            self.studentAsAppUser = try? await dataService.fetchUser(withId: studentID)
        }
        
        if let data = try? await communityManager.fetchInstructorStudentData(instructorID: instructorID, studentID: studentID, isOffline: isOffline) {
            self.currentProgress = data.progress ?? 0.0
            self.studentNotes = data.notes ?? []
        } else {
            self.currentProgress = student.averageProgress
        }
    }
    
    func saveOrUpdateNote() async {
        guard let instructorID = authManager.user?.id, let studentID = student.id else { return }
        let text = noteText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        
        do {
            if let noteToUpdate = editingNote {
                // Update existing
                try await communityManager.updateStudentNote(instructorID: instructorID, studentID: studentID, oldNote: noteToUpdate, newContent: text, isOffline: isOffline)
            } else {
                // Create new
                try await communityManager.addStudentNote(instructorID: instructorID, studentID: studentID, noteContent: text, isOffline: isOffline)
            }
            isShowingNoteSheet = false
            await fetchData()
        } catch {
            print("Error saving note: \(error)")
            self.errorMessage = "Could not save note. Check Firestore Permissions."
            self.isShowingErrorAlert = true
        }
    }
    
    func deleteNote(_ note: StudentNote) async {
        guard let instructorID = authManager.user?.id, let studentID = student.id else { return }
        do {
            try await communityManager.deleteStudentNote(instructorID: instructorID, studentID: studentID, note: note, isOffline: isOffline)
            await fetchData()
        } catch {
            self.errorMessage = "Could not delete note: \(error.localizedDescription)"
            self.isShowingErrorAlert = true
        }
    }
    
    func saveProgress() async {
        guard let instructorID = authManager.user?.id, let studentID = student.id else { return }
        
        do {
            try await communityManager.updateStudentProgress(instructorID: instructorID, studentID: studentID, newProgress: newProgressValue, isOffline: isOffline)
            self.currentProgress = newProgressValue
            isShowingProgressSheet = false
        } catch {
            print("Error updating progress: \(error)")
            self.errorMessage = "Could not update progress. Check Firestore Permissions."
            self.isShowingErrorAlert = true
        }
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
                QuickActionButton(title: "Add Note", icon: "note.text.badge.plus", color: .orange, action: onAddNote)
                QuickActionButton(title: "Update Progress", icon: "arrow.up.circle.fill", color: .accentGreen, action: onUpdateProgress)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.08), radius: 4, y: 2)
    }
}

struct NotesCard: View {
    let notes: [StudentNote]
    let onEdit: (StudentNote) -> Void
    let onDelete: (StudentNote) -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("INSTRUCTOR NOTES")
                .font(.system(size: 13, weight: .bold))
                .foregroundColor(.secondary)
                .padding([.horizontal, .top], 16)
                .padding(.bottom, 8)
            Divider().padding(.horizontal, 16)
            
            if notes.isEmpty {
                Text("No notes added yet.")
                    .font(.subheadline)
                    .foregroundColor(.textLight)
                    .padding(16)
            } else {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(notes.sorted(by: { $0.timestamp > $1.timestamp })) { note in
                        HStack(alignment: .top) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(note.content)
                                    .font(.body)
                                    .foregroundColor(.textDark)
                                Text(note.timestamp.formatted(date: .abbreviated, time: .shortened))
                                    .font(.caption)
                                    .foregroundColor(.textLight)
                            }
                            Spacer()
                            
                            // Edit/Delete Menu
                            Menu {
                                Button { onEdit(note) } label: {
                                    Label("Edit", systemImage: "pencil")
                                }
                                Button(role: .destructive) { onDelete(note) } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            } label: {
                                Image(systemName: "ellipsis")
                                    .foregroundColor(.textLight)
                                    .padding(10)
                            }
                        }
                        .padding(16)
                        
                        if note.id != notes.last?.id {
                            Divider().padding(.horizontal, 16)
                        }
                    }
                }
            }
        }
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.08), radius: 4, y: 2)
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
