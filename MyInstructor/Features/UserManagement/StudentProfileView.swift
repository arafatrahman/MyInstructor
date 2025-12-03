// File: arafatrahman/myinstructor/MyInstructor-main/MyInstructor/Features/UserManagement/StudentProfileView.swift
// --- UPDATED: Removed 'Track Exam' button from header ---

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
    @State private var studentNotes: [StudentNote] = []
    @State private var currentProgress: Double = 0.0
    
    // Alert states
    @State private var isShowingRemoveAlert = false
    @State private var isShowingBlockAlert = false
    @State private var isShowingDeleteAlert = false
    @State private var isShowingErrorAlert = false
    @State private var errorMessage = ""
    
    // Sheet states
    @State private var isShowingEditSheet = false
    @State private var isShowingNoteSheet = false
    @State private var isShowingProgressSheet = false
    
    @State private var noteText = ""
    @State private var editingNote: StudentNote? = nil
    @State private var newProgressValue: Double = 0.0
    
    var isOffline: Bool { student.isOffline }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Header
                ProfileHeaderView(
                    student: student,
                    studentAsAppUser: studentAsAppUser,
                    onAddNote: { editingNote = nil; noteText = ""; isShowingNoteSheet = true },
                    onUpdateProgress: { newProgressValue = currentProgress; isShowingProgressSheet = true }
                )
                .padding(.horizontal).padding(.top, 16)
                
                ProgressCard(overallProgress: currentProgress).padding(.horizontal)
                
                NotesCard(
                    notes: studentNotes,
                    onEdit: { note in editingNote = note; noteText = note.content; isShowingNoteSheet = true },
                    onDelete: { note in Task { await deleteNote(note) } }
                )
                .padding(.horizontal)
                
                LessonsCard(lessons: lessonHistory).padding(.horizontal)
                PaymentsCard(payments: payments).padding(.horizontal)
                
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
            VStack(spacing: 20) {
                Capsule().fill(Color.secondary.opacity(0.3)).frame(width: 40, height: 5).padding(.top, 12)
                HStack {
                    Text(editingNote == nil ? "New Note" : "Edit Note").font(.title2).bold().foregroundColor(.primary)
                    Spacer()
                    Button { isShowingNoteSheet = false } label: { Image(systemName: "xmark.circle.fill").font(.title2).foregroundColor(.secondary) }
                }.padding(.horizontal, 20)
                ZStack(alignment: .topLeading) {
                    if noteText.isEmpty { Text("Write your observations...").foregroundColor(Color(.placeholderText)).padding(16).allowsHitTesting(false) }
                    TextEditor(text: $noteText).scrollContentBackground(.hidden).padding(10).background(Color(.secondarySystemBackground)).cornerRadius(16)
                }.padding(.horizontal, 20)
                Button { Task { await saveOrUpdateNote() } } label: {
                    HStack { if noteText.isEmpty { Text("Save Note") } else { Image(systemName: "checkmark.circle.fill"); Text("Save Note") } }
                    .font(.headline).foregroundColor(.white).frame(maxWidth: .infinity).padding(.vertical, 16)
                    .background(noteText.isEmpty ? Color.secondary.opacity(0.3) : Color.primaryBlue).cornerRadius(16)
                }.disabled(noteText.isEmpty).padding(.horizontal, 20).padding(.bottom, 10)
            }.background(Color(.systemBackground)).presentationDetents([.medium, .large])
        }
        .sheet(isPresented: $isShowingProgressSheet) {
            NavigationView {
                VStack(spacing: 30) {
                    CircularProgressView(progress: newProgressValue, color: .primaryBlue, size: 120).padding(.top, 20)
                    VStack { Text("\(Int(newProgressValue * 100))%").font(.largeTitle).bold(); Text("Mastery Level").foregroundColor(.secondary) }
                    Slider(value: $newProgressValue, in: 0.0...1.0, step: 0.05).tint(.primaryBlue).padding(.horizontal, 40)
                    Spacer()
                }
                .navigationTitle("Update Progress").navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .navigationBarLeading) { Button("Cancel") { isShowingProgressSheet = false } }; ToolbarItem(placement: .navigationBarTrailing) { Button("Update") { Task { await saveProgress() } } } }
            }.presentationDetents([.medium])
        }
        .sheet(isPresented: $isShowingEditSheet) {
            OfflineStudentFormView(studentToEdit: OfflineStudent(id: student.id, instructorID: authManager.user?.id ?? "", name: student.name, phone: student.phone, email: student.email, address: student.address), onStudentAdded: { dismiss() })
        }
        
        .alert("Error", isPresented: $isShowingErrorAlert) { Button("OK", role: .cancel) { } } message: { Text(errorMessage) }
        .alert("Remove?", isPresented: $isShowingRemoveAlert) { Button("Cancel", role: .cancel) { }; Button("Remove", role: .destructive) { Task { await removeStudent() } } }
        .alert("Block?", isPresented: $isShowingBlockAlert) { Button("Cancel", role: .cancel) { }; Button("Block", role: .destructive) { Task { await blockStudent() } } }
        .alert("Delete?", isPresented: $isShowingDeleteAlert) { Button("Cancel", role: .cancel) { }; Button("Delete", role: .destructive) { Task { await deleteOfflineStudent() } } }
    }
    
    // ... (Helper Methods)
    func fetchData() async {
        guard let instructorID = authManager.user?.id, let studentID = student.id else { return }
        if !isOffline && studentAsAppUser == nil { self.studentAsAppUser = try? await dataService.fetchUser(withId: studentID) }
        if let data = try? await communityManager.fetchInstructorStudentData(instructorID: instructorID, studentID: studentID, isOffline: isOffline) {
            self.currentProgress = data.progress ?? 0.0; self.studentNotes = data.notes ?? []
        } else { self.currentProgress = student.averageProgress }
        self.lessonHistory = (try? await lessonManager.fetchLessonsForStudent(studentID: studentID, start: .distantPast, end: .distantFuture)) ?? []
        self.payments = (try? await paymentManager.fetchStudentPayments(for: studentID)) ?? []
    }
    
    func saveOrUpdateNote() async {
        guard let instructorID = authManager.user?.id, let studentID = student.id else { return }
        let text = noteText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        do {
            if let noteToUpdate = editingNote {
                try await communityManager.updateStudentNote(instructorID: instructorID, studentID: studentID, oldNote: noteToUpdate, newContent: text, isOffline: isOffline)
            } else {
                try await communityManager.addStudentNote(instructorID: instructorID, studentID: studentID, noteContent: text, isOffline: isOffline)
            }
            isShowingNoteSheet = false; await fetchData()
        } catch { errorMessage = "Error saving note."; isShowingErrorAlert = true }
    }
    
    func deleteNote(_ note: StudentNote) async {
        guard let instructorID = authManager.user?.id, let studentID = student.id else { return }
        try? await communityManager.deleteStudentNote(instructorID: instructorID, studentID: studentID, note: note, isOffline: isOffline); await fetchData()
    }
    
    func saveProgress() async {
        guard let instructorID = authManager.user?.id, let studentID = student.id else { return }
        try? await communityManager.updateStudentProgress(instructorID: instructorID, studentID: studentID, newProgress: newProgressValue, isOffline: isOffline)
        currentProgress = newProgressValue; isShowingProgressSheet = false
    }
    
    func removeStudent() async { try? await communityManager.removeStudent(studentID: student.id!, instructorID: authManager.user!.id!); dismiss() }
    func blockStudent() async { try? await communityManager.blockStudent(studentID: student.id!, instructorID: authManager.user!.id!); dismiss() }
    func deleteOfflineStudent() async { try? await communityManager.deleteOfflineStudent(studentID: student.id!); dismiss() }
}

struct ProfileHeaderView: View {
    let student: Student
    let studentAsAppUser: AppUser?
    let onAddNote: () -> Void
    let onUpdateProgress: () -> Void
    // Removed onTrackExam
    
    var body: some View {
        VStack(spacing: 15) {
            HStack(alignment: .top) {
                AsyncImage(url: URL(string: student.photoURL ?? "")) { phase in
                    if let image = phase.image { image.resizable().scaledToFill() }
                    else { Image(systemName: "person.crop.circle.fill").resizable().foregroundColor(.primaryBlue) }
                }.frame(width: 70, height: 70).background(Color.secondaryGray).clipShape(Circle())
                
                VStack(alignment: .leading) {
                    Text(student.name).font(.title2).bold()
                    Text(student.email).font(.subheadline).foregroundColor(.textLight)
                }
                Spacer()
                
                HStack(spacing: 15) {
                    if let phone = student.phone, !phone.isEmpty {
                        Button { if let url = URL(string: "tel:\(phone.filter("0123456789+".contains))") { UIApplication.shared.open(url) } }
                        label: { Image(systemName: "phone.circle.fill").foregroundColor(.accentGreen).font(.title) }
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

// ... (Other cards)
struct NotesCard: View { let notes: [StudentNote]; let onEdit: (StudentNote)->Void; let onDelete: (StudentNote)->Void; var body: some View { /*...*/ EmptyView() } }
struct LessonsCard: View { let lessons: [Lesson]; var body: some View { /*...*/ EmptyView() } }
struct PaymentsCard: View { let payments: [Payment]; var body: some View { /*...*/ EmptyView() } }
struct ProgressCard: View { let overallProgress: Double; var body: some View { /*...*/ EmptyView() } }
