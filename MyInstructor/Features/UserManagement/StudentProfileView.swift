// File: arafatrahman/myinstructor/MyInstructor-main/MyInstructor/Features/UserManagement/StudentProfileView.swift
// --- UPDATED: 'Remove' moves to Completed. 'Reactivate' button added. ---

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
    
    @State private var studentStatus: RequestStatus = .approved
    
    // Alert states
    @State private var isShowingRemoveAlert = false
    @State private var isShowingBlockAlert = false
    @State private var isShowingUnblockAlert = false
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
                
                // 1. Header Card (Photo, Name, Actions)
                StudentProfileHeaderCard(
                    student: student,
                    studentAsAppUser: studentAsAppUser,
                    onEdit: { isShowingEditSheet = true }
                )
                .padding(.horizontal)
                .padding(.top, 16)
                
                // 2. Progress Card
                StudentProgressCard(
                    progress: currentProgress,
                    onUpdate: {
                        newProgressValue = currentProgress
                        isShowingProgressSheet = true
                    }
                )
                .padding(.horizontal)
                
                // 3. Contact Card
                StudentContactCard(student: student)
                    .padding(.horizontal)
                
                // 4. Notes Card
                StudentNotesCard(
                    notes: studentNotes,
                    onAdd: {
                        editingNote = nil
                        noteText = ""
                        isShowingNoteSheet = true
                    },
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
                
                // 5. Lessons Card
                StudentLessonsCard(lessons: lessonHistory)
                    .padding(.horizontal)
                
                // 6. Payments Card
                StudentPaymentsCard(payments: payments)
                    .padding(.horizontal)
                
                Spacer(minLength: 20)
            }
            .padding(.bottom, 20)
        }
        .navigationTitle("Student Profile")
        .navigationBarTitleDisplayMode(.inline)
        // --- TOOLBAR ---
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Menu {
                    if isOffline {
                        Button { isShowingEditSheet = true } label: { Label("Edit Profile", systemImage: "pencil") }
                        Button(role: .destructive) { isShowingDeleteAlert = true } label: { Label("Delete Student", systemImage: "trash") }
                    } else {
                        // --- COMPLETED / REMOVED LOGIC ---
                        if studentStatus == .completed {
                            Button { Task { await reactivateStudent() } } label: { Label("Reactivate Student", systemImage: "person.badge.plus") }
                        } else {
                            Button(role: .destructive) { isShowingRemoveAlert = true } label: { Label("Remove Student", systemImage: "person.badge.minus") }
                        }
                        
                        // --- BLOCK / UNBLOCK LOGIC ---
                        if studentStatus == .blocked {
                            Button { isShowingUnblockAlert = true } label: { Label("Unblock Student", systemImage: "hand.raised.slash.fill") }
                        } else {
                            Button(role: .destructive) { isShowingBlockAlert = true } label: { Label("Block Student", systemImage: "hand.raised.fill") }
                        }
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
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
            OfflineStudentFormView(studentToEdit: OfflineStudent(id: student.id, instructorID: authManager.user?.id ?? "", name: student.name, phone: student.phone, email: student.email, address: student.address), onStudentAdded: {
                Task { await fetchData() }
            })
        }
        
        .alert("Error", isPresented: $isShowingErrorAlert) { Button("OK", role: .cancel) { } } message: { Text(errorMessage) }
        
        .alert("Remove Student?", isPresented: $isShowingRemoveAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Remove", role: .destructive) { Task { await removeStudent() } }
        } message: { Text("This will move the student to the Completed list.") }
        
        .alert("Block Student?", isPresented: $isShowingBlockAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Block", role: .destructive) { Task { await blockStudent() } }
        } message: { Text("They won't be able to contact you.") }
        
        .alert("Unblock Student?", isPresented: $isShowingUnblockAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Unblock", role: .none) { Task { await unblockStudent() } }
        } message: { Text("They will be added back to your list.") }
        
        .alert("Delete Student?", isPresented: $isShowingDeleteAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) { Task { await deleteOfflineStudent() } }
        } message: { Text("This action cannot be undone.") }
    }
    
    // MARK: - Logic Methods
    func fetchData() async {
        guard let instructorID = authManager.user?.id, let studentID = student.id else { return }
        
        // 1. Fetch User Object if Online
        if !isOffline && studentAsAppUser == nil {
            self.studentAsAppUser = try? await dataService.fetchUser(withId: studentID)
            
            // --- NEW: Fetch Status ---
            if let status = try? await communityManager.fetchRelationshipStatus(instructorID: instructorID, studentID: studentID) {
                self.studentStatus = status
            }
        }
        
        // 2. Fetch Notes & Progress
        if let data = try? await communityManager.fetchInstructorStudentData(instructorID: instructorID, studentID: studentID, isOffline: isOffline) {
            self.currentProgress = data.progress ?? 0.0
            self.studentNotes = data.notes ?? []
        } else {
            self.currentProgress = student.averageProgress
        }
        
        // 3. Fetch Lessons
        do {
            let allLessons = try await lessonManager.fetchLessonsForStudent(studentID: studentID, start: .distantPast, end: .distantFuture)
            self.lessonHistory = allLessons.sorted(by: { $0.startTime > $1.startTime })
        } catch { print("Error fetching lessons: \(error)") }
        
        // 4. Fetch Payments
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
            isShowingNoteSheet = false
            await fetchData()
        } catch { errorMessage = "Error saving note."; isShowingErrorAlert = true }
    }
    
    func deleteNote(_ note: StudentNote) async {
        guard let instructorID = authManager.user?.id, let studentID = student.id else { return }
        try? await communityManager.deleteStudentNote(instructorID: instructorID, studentID: studentID, note: note, isOffline: isOffline)
        await fetchData()
    }
    
    func saveProgress() async {
        guard let instructorID = authManager.user?.id, let studentID = student.id else { return }
        try? await communityManager.updateStudentProgress(instructorID: instructorID, studentID: studentID, newProgress: newProgressValue, isOffline: isOffline)
        currentProgress = newProgressValue
        isShowingProgressSheet = false
    }
    
    func removeStudent() async {
        // Optimistic update
        self.studentStatus = .completed
        try? await communityManager.removeStudent(studentID: student.id!, instructorID: authManager.user!.id!)
        dismiss()
    }
    
    func reactivateStudent() async {
        // Optimistic update
        self.studentStatus = .approved
        try? await communityManager.reactivateStudent(studentID: student.id!, instructorID: authManager.user!.id!)
    }
    
    func blockStudent() async {
        self.studentStatus = .blocked
        try? await communityManager.blockStudent(studentID: student.id!, instructorID: authManager.user!.id!)
        dismiss()
    }
    
    func unblockStudent() async {
        self.studentStatus = .approved
        try? await communityManager.unblockStudent(studentID: student.id!, instructorID: authManager.user!.id!)
        await fetchData()
    }
    
    func deleteOfflineStudent() async {
        try? await communityManager.deleteOfflineStudent(studentID: student.id!)
        dismiss()
    }
}

// MARK: - 1. Student Header Card
private struct StudentProfileHeaderCard: View {
    let student: Student
    let studentAsAppUser: AppUser?
    let onEdit: () -> Void
    
    private var profileImageURL: URL? {
        guard let urlString = student.photoURL, !urlString.isEmpty else { return nil }
        return URL(string: urlString)
    }
    
    var body: some View {
        VStack(spacing: 12) {
            ZStack(alignment: .bottomTrailing) {
                AsyncImage(url: profileImageURL) { phase in
                    if let image = phase.image {
                        image.resizable().scaledToFill()
                    } else {
                        Image(systemName: "person.crop.circle.fill").resizable().foregroundColor(.secondary)
                    }
                }
                .frame(width: 100, height: 100)
                .background(Color(.systemGray5))
                .clipShape(Circle())
                .overlay(Circle().stroke(Color.primaryBlue, lineWidth: 3))
                
                if student.isOffline {
                    Button(action: onEdit) {
                        Image(systemName: "pencil.circle.fill").font(.title).foregroundColor(.primaryBlue).background(Circle().fill(.white))
                    }.offset(x: 5, y: 5)
                }
            }
            .padding(.top, 20)
            
            Text(student.name).font(.system(size: 22, weight: .semibold)).foregroundColor(.primary)
            Text(student.isOffline ? "Offline Student" : "Active Student").font(.system(size: 15)).foregroundColor(.secondary).padding(.bottom, 4)
            
            HStack(spacing: 20) {
                if let phone = student.phone, !phone.isEmpty {
                    Button { if let url = URL(string: "tel:\(phone.filter("0123456789+".contains))") { UIApplication.shared.open(url) } } label: {
                        VStack(spacing: 4) {
                            Image(systemName: "phone.fill").font(.system(size: 20)).frame(width: 44, height: 44).background(Color.accentGreen.opacity(0.1)).foregroundColor(.accentGreen).clipShape(Circle())
                            Text("Call").font(.caption)
                        }
                    }
                }
                if let appUser = studentAsAppUser {
                    NavigationLink(destination: ChatLoadingView(otherUser: appUser)) {
                        VStack(spacing: 4) {
                            Image(systemName: "message.fill").font(.system(size: 20)).frame(width: 44, height: 44).background(Color.primaryBlue.opacity(0.1)).foregroundColor(.primaryBlue).clipShape(Circle())
                            Text("Chat").font(.caption)
                        }
                    }
                }
            }.padding(.bottom, 16)
        }
        .frame(maxWidth: .infinity).background(Color(.systemBackground)).cornerRadius(16).shadow(color: Color.black.opacity(0.08), radius: 4, y: 2)
    }
}

// MARK: - 2. Progress Card
private struct StudentProgressCard: View {
    let progress: Double; let onUpdate: () -> Void
    var body: some View {
        VStack(spacing: 4) {
            Text("Mastery Level").font(.system(size: 15)).foregroundColor(.white.opacity(0.9))
            Text("\(Int(progress * 100))%").font(.system(size: 36, weight: .bold)).foregroundColor(.white)
            Text("Ready for test?").font(.system(size: 15)).foregroundColor(.white.opacity(0.9))
            Button(action: onUpdate) { Text("Update Progress").font(.caption).bold().padding(.horizontal, 12).padding(.vertical, 6).background(Color.white.opacity(0.2)).cornerRadius(12).foregroundColor(.white) }.padding(.top, 5)
        }
        .padding(20).frame(maxWidth: .infinity).background(LinearGradient(gradient: Gradient(colors: [Color.primaryBlue, Color(red: 0.35, green: 0.34, blue: 0.84)]), startPoint: .topLeading, endPoint: .bottomTrailing)).cornerRadius(16).shadow(color: Color.primaryBlue.opacity(0.4), radius: 8, y: 4)
    }
}

// MARK: - 3. Contact Card
private struct StudentContactCard: View {
    let student: Student
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("CONTACT").font(.system(size: 13, weight: .bold)).foregroundColor(.secondary).padding(.horizontal, 16).padding(.top, 12).padding(.bottom, 8)
            Divider().padding(.horizontal, 16)
            ContactRow(icon: "envelope.fill", label: "Email", value: student.email.isEmpty ? "Not provided" : student.email)
            ContactRow(icon: "phone.fill", label: "Phone", value: student.phone ?? "Not provided")
            ContactRow(icon: "mappin.and.ellipse", label: "Address", value: student.address ?? "Not provided")
        }.background(Color(.systemBackground)).cornerRadius(16).shadow(color: Color.black.opacity(0.08), radius: 4, y: 2)
    }
}

// MARK: - 4. Notes Card
private struct StudentNotesCard: View {
    let notes: [StudentNote]; let onAdd: () -> Void; let onEdit: (StudentNote) -> Void; let onDelete: (StudentNote) -> Void
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack { Text("NOTES").font(.system(size: 13, weight: .bold)).foregroundColor(.secondary); Spacer(); Button(action: onAdd) { Image(systemName: "plus").font(.system(size: 14, weight: .bold)).foregroundColor(.primaryBlue) } }.padding(.horizontal, 16).padding(.top, 12).padding(.bottom, 8)
            Divider().padding(.horizontal, 16)
            if !notes.isEmpty {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(notes) { note in
                        VStack(alignment: .leading, spacing: 6) {
                            HStack(alignment: .top) {
                                Text(note.content).font(.system(size: 15)).foregroundColor(.primary).fixedSize(horizontal: false, vertical: true); Spacer()
                                Menu { Button(action: { onEdit(note) }) { Label("Edit", systemImage: "pencil") }; Button(role: .destructive, action: { onDelete(note) }) { Label("Delete", systemImage: "trash") } } label: { Image(systemName: "ellipsis").foregroundColor(.secondary).padding(4) }
                            }
                            Text(note.timestamp.formatted(date: .abbreviated, time: .shortened)).font(.system(size: 12)).foregroundColor(.secondary)
                        }.padding(.horizontal, 16).padding(.vertical, 12)
                        if note.id != notes.last?.id { Divider().padding(.horizontal, 16) }
                    }
                }
            } else { Text("No notes added.").font(.system(size: 15)).foregroundColor(.secondary).padding(16) }
        }.background(Color(.systemBackground)).cornerRadius(16).shadow(color: Color.black.opacity(0.08), radius: 4, y: 2)
    }
}

// MARK: - 5. Lessons Card
private struct StudentLessonsCard: View {
    let lessons: [Lesson]; var recentLessons: [Lesson] { Array(lessons.prefix(3)) }
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("RECENT LESSONS").font(.system(size: 13, weight: .bold)).foregroundColor(.secondary).padding(.horizontal, 16).padding(.top, 12).padding(.bottom, 8)
            Divider().padding(.horizontal, 16)
            if !recentLessons.isEmpty {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(recentLessons) { lesson in
                        HStack {
                            VStack(alignment: .leading, spacing: 2) { Text(lesson.topic).font(.system(size: 16, weight: .medium)).foregroundColor(.primary); Text(lesson.startTime.formatted(date: .abbreviated, time: .shortened)).font(.system(size: 13)).foregroundColor(.secondary) }
                            Spacer()
                            Text(lesson.status.rawValue.capitalized).font(.system(size: 12, weight: .bold)).padding(.horizontal, 8).padding(.vertical, 4).background(statusColor(lesson.status).opacity(0.15)).foregroundColor(statusColor(lesson.status)).cornerRadius(8)
                        }.padding(.horizontal, 16).padding(.vertical, 12)
                        if lesson.id != recentLessons.last?.id { Divider().padding(.horizontal, 16) }
                    }
                }
            } else { Text("No lessons recorded.").font(.system(size: 15)).foregroundColor(.secondary).padding(16) }
        }.background(Color(.systemBackground)).cornerRadius(16).shadow(color: Color.black.opacity(0.08), radius: 4, y: 2)
    }
    func statusColor(_ status: LessonStatus) -> Color { switch status { case .completed: return .accentGreen; case .cancelled: return .warningRed; case .scheduled: return .primaryBlue } }
}

// MARK: - 6. Payments Card
private struct StudentPaymentsCard: View {
    let payments: [Payment]; var recentPayments: [Payment] { Array(payments.sorted(by: { $0.date > $1.date }).prefix(3)) }
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("RECENT PAYMENTS").font(.system(size: 13, weight: .bold)).foregroundColor(.secondary).padding(.horizontal, 16).padding(.top, 12).padding(.bottom, 8)
            Divider().padding(.horizontal, 16)
            if !recentPayments.isEmpty {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(recentPayments) { payment in
                        HStack {
                            VStack(alignment: .leading, spacing: 2) { Text(payment.isPaid ? "Paid" : "Pending").font(.system(size: 16, weight: .medium)).foregroundColor(payment.isPaid ? .primary : .warningRed); Text(payment.date.formatted(date: .abbreviated, time: .omitted)).font(.system(size: 13)).foregroundColor(.secondary) }
                            Spacer()
                            Text(payment.amount, format: .currency(code: "GBP")).font(.system(size: 16, weight: .semibold)).foregroundColor(.primary)
                        }.padding(.horizontal, 16).padding(.vertical, 12)
                        if payment.id != recentPayments.last?.id { Divider().padding(.horizontal, 16) }
                    }
                }
            } else { Text("No payments recorded.").font(.system(size: 15)).foregroundColor(.secondary).padding(16) }
        }.background(Color(.systemBackground)).cornerRadius(16).shadow(color: Color.black.opacity(0.08), radius: 4, y: 2)
    }
}
