// File: arafatrahman/myinstructor/MyInstructor-main/MyInstructor/Features/Lessons/AddExamFormView.swift
// --- UPDATED: Pass initiatorID for notifications on Save/Delete ---

import SwiftUI

struct AddExamFormView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var lessonManager: LessonManager
    @EnvironmentObject var authManager: AuthManager
    @EnvironmentObject var dataService: DataService
    
    // If nil, user must select a student (Instructor mode)
    var studentID: String?
    var examToEdit: ExamResult?
    var onSave: () -> Void
    
    // --- Student Selection State ---
    @State private var allStudents: [SelectableStudent] = []
    @State private var selectedStudent: SelectableStudent? = nil
    
    // Form State
    @State private var date = Date()
    @State private var testCenter = ""
    @State private var status: ExamStatus = .scheduled
    
    // Result State
    @State private var isPass = false
    @State private var minorFaults = 0
    @State private var seriousFaults = 0
    @State private var notes = ""
    
    @State private var isLoading = false
    @State private var errorMessage: String?
    
    // --- NEW: Alert State ---
    @State private var isShowingDeleteAlert = false
    
    var isEditing: Bool { examToEdit != nil }
    var effectiveStudentID: String? {
        studentID ?? selectedStudent?.id
    }
    
    var body: some View {
        NavigationView {
            Form {
                // --- Student Selection (If needed) ---
                if studentID == nil {
                    Section("Student") {
                        Picker("Select Student", selection: $selectedStudent) {
                            Text("Select Student").tag(nil as SelectableStudent?)
                            
                            Section("Online Students") {
                                ForEach(allStudents.filter { !$0.isOffline }) { student in
                                    Text(student.name).tag(student as SelectableStudent?)
                                }
                            }
                            Section("Offline Students") {
                                ForEach(allStudents.filter { $0.isOffline }) { student in
                                    Text(student.name).tag(student as SelectableStudent?)
                                }
                            }
                        }
                        .disabled(isEditing) // Can't change student when editing
                    }
                }
                
                Section("Exam Schedule") {
                    DatePicker("Date & Time", selection: $date, displayedComponents: [.date, .hourAndMinute])
                    
                    TextField("Test Center", text: $testCenter)
                        .textContentType(.location)
                }
                
                Section("Status") {
                    Picker("Status", selection: $status) {
                        Text("Scheduled").tag(ExamStatus.scheduled)
                        Text("Completed").tag(ExamStatus.completed)
                    }
                    .pickerStyle(.segmented)
                }
                
                if status == .completed {
                    Section("Result") {
                        Toggle("Passed", isOn: $isPass)
                            .tint(.accentGreen)
                        
                        Stepper("Minor Faults: \(minorFaults)", value: $minorFaults, in: 0...50)
                        
                        Stepper("Serious/Dangerous: \(seriousFaults)", value: $seriousFaults, in: 0...10)
                        
                        if !isPass && seriousFaults == 0 {
                            Text("⚠️ Usually a fail requires at least 1 serious fault.").font(.caption).foregroundColor(.orange)
                        }
                    }
                    
                    Section("Feedback / Reason") {
                        TextField("Examiner notes...", text: $notes)
                    }
                }
                
                if let error = errorMessage {
                    Section {
                        Text(error).foregroundColor(.red).font(.caption)
                    }
                }
                
                // --- DELETE BUTTON ---
                if isEditing {
                    Section {
                        Button(role: .destructive) {
                            isShowingDeleteAlert = true
                        } label: {
                            HStack {
                                Spacer()
                                Text("Delete Exam")
                                Spacer()
                            }
                        }
                    }
                }
            }
            .navigationTitle(isEditing ? "Edit Exam" : "Track Exam")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { saveExam() }
                        .bold()
                        .disabled(testCenter.isEmpty || isLoading || effectiveStudentID == nil)
                }
            }
            .task {
                await loadInitialData()
            }
            // --- DELETE ALERT ---
            .alert("Delete Exam?", isPresented: $isShowingDeleteAlert) {
                Button("Cancel", role: .cancel) { }
                Button("Delete", role: .destructive) {
                    deleteExam()
                }
            } message: {
                Text("Are you sure you want to delete this exam record? This cannot be undone.")
            }
        }
    }
    
    private func loadInitialData() async {
        // If no student ID provided, fetch list for picker
        if studentID == nil {
            await fetchAllStudents()
        }
        
        if let exam = examToEdit {
            date = exam.date
            testCenter = exam.testCenter
            status = exam.status
            isPass = exam.isPass ?? false
            minorFaults = exam.minorFaults ?? 0
            seriousFaults = exam.seriousFaults ?? 0
            notes = exam.notes ?? ""
            
            // If we have the list loaded, set the selected student
            if studentID == nil {
                // Find student in list
                self.selectedStudent = allStudents.first(where: { $0.id == exam.studentID })
            }
        }
    }
    
    private func fetchAllStudents() async {
        guard let instructorID = authManager.user?.id else { return }
        
        do {
            async let onlineStudents = dataService.fetchStudents(for: instructorID)
            async let offlineStudents = dataService.fetchOfflineStudents(for: instructorID)
            
            let online = try await onlineStudents
            let offline = try await offlineStudents
            
            let selectableOnline = online.map { SelectableStudent(student: $0) }
            let selectableOffline = offline.map { SelectableStudent(offlineStudent: $0) }
            
            self.allStudents = (selectableOnline + selectableOffline).sorted(by: { $0.name < $1.name })
            
        } catch {
            print("Failed to load students: \(error.localizedDescription)")
        }
    }
    
    private func saveExam() {
        guard let finalStudentID = effectiveStudentID, let currentUserID = authManager.user?.id else {
            errorMessage = "Please select a student or sign in."
            return
        }
        
        isLoading = true
        
        var linkedInstructorID: String? = nil
        if authManager.role == .instructor {
            linkedInstructorID = authManager.user?.id
        } else {
            linkedInstructorID = authManager.user?.instructorIDs?.first
        }
        
        let exam = ExamResult(
            id: examToEdit?.id,
            studentID: finalStudentID,
            instructorID: linkedInstructorID,
            date: date,
            testCenter: testCenter,
            status: status,
            isPass: status == .completed ? isPass : nil,
            minorFaults: status == .completed ? minorFaults : nil,
            seriousFaults: status == .completed ? seriousFaults : nil,
            notes: notes.isEmpty ? nil : notes
        )
        
        Task {
            do {
                if isEditing {
                    try await lessonManager.updateExamResult(exam, initiatorID: currentUserID)
                } else {
                    try await lessonManager.logExamResult(exam, initiatorID: currentUserID)
                }
                onSave()
                dismiss()
            } catch {
                errorMessage = "Failed: \(error.localizedDescription)"
            }
            isLoading = false
        }
    }
    
    private func deleteExam() {
        guard let id = examToEdit?.id, let currentUserID = authManager.user?.id else { return }
        isLoading = true
        Task {
            do {
                try await lessonManager.deleteExamResult(id: id, initiatorID: currentUserID)
                onSave() // Refresh list
                dismiss()
            } catch {
                errorMessage = "Failed to delete: \(error.localizedDescription)"
                isLoading = false
            }
        }
    }
}
