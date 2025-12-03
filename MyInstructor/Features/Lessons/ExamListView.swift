// File: arafatrahman/myinstructor/MyInstructor-main/MyInstructor/Features/Lessons/ExamListView.swift
// --- UPDATED: Handles Instructor 'All Exams' View ---

import SwiftUI

struct ExamListView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var lessonManager: LessonManager
    @EnvironmentObject var authManager: AuthManager
    
    // Optional: If nil, we infer context based on role
    var studentID: String?
    
    @State private var exams: [ExamResult] = []
    @State private var isLoading = true
    @State private var isAddSheetPresented = false
    @State private var examToEdit: ExamResult? = nil
    
    var scheduledExams: [ExamResult] {
        exams.filter { $0.status == .scheduled }.sorted(by: { $0.date < $1.date })
    }
    
    var pastExams: [ExamResult] {
        exams.filter { $0.status == .completed }.sorted(by: { $0.date > $1.date })
    }
    
    var body: some View {
        NavigationView {
            VStack {
                if isLoading {
                    ProgressView("Loading Exams...")
                } else if exams.isEmpty {
                    EmptyStateView(
                        icon: "flag.checkered",
                        message: "No exam records found.",
                        actionTitle: "Schedule Exam",
                        action: { isAddSheetPresented = true }
                    )
                } else {
                    List {
                        // UPCOMING
                        if !scheduledExams.isEmpty {
                            Section("Upcoming") {
                                ForEach(scheduledExams) { exam in
                                    Button { examToEdit = exam } label: {
                                        ExamRow(exam: exam, showStudentName: studentID == nil && authManager.role == .instructor)
                                    }
                                    .buttonStyle(.plain)
                                }
                                .onDelete(perform: deleteScheduled)
                            }
                        }
                        
                        // HISTORY
                        if !pastExams.isEmpty {
                            Section("History") {
                                ForEach(pastExams) { exam in
                                    Button { examToEdit = exam } label: {
                                        ExamRow(exam: exam, showStudentName: studentID == nil && authManager.role == .instructor)
                                    }
                                    .buttonStyle(.plain)
                                }
                                .onDelete(perform: deletePast)
                            }
                        }
                    }
                    .listStyle(.insetGrouped)
                }
            }
            .navigationTitle("Track Exams")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") { dismiss() }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button { isAddSheetPresented = true } label: {
                        Image(systemName: "plus").font(.headline)
                    }
                }
            }
            // Pass the studentID (if specific) or nil (if instructor needs to select)
            .sheet(isPresented: $isAddSheetPresented) {
                AddExamFormView(studentID: studentID, onSave: { Task { await fetchData() } })
            }
            .sheet(item: $examToEdit) { exam in
                AddExamFormView(studentID: studentID, examToEdit: exam, onSave: {
                    examToEdit = nil
                    Task { await fetchData() }
                })
            }
            .task { await fetchData() }
        }
    }
    
    func fetchData() async {
        isLoading = true
        do {
            if let specificID = studentID {
                // Case 1: Viewing a specific student (Student Dashboard OR Instructor -> Student Profile)
                self.exams = try await lessonManager.fetchExamResults(for: specificID)
            } else if authManager.role == .instructor, let instructorID = authManager.user?.id {
                // Case 2: Instructor Dashboard -> View ALL student exams
                self.exams = try await lessonManager.fetchExamsForInstructor(instructorID: instructorID)
            } else if let myID = authManager.user?.id {
                // Case 3: Student fallback
                self.exams = try await lessonManager.fetchExamResults(for: myID)
            }
        } catch {
            print("Error fetching exams: \(error)")
        }
        isLoading = false
    }
    
    func deleteScheduled(at offsets: IndexSet) {
        deleteItems(at: offsets, from: scheduledExams)
    }
    
    func deletePast(at offsets: IndexSet) {
        deleteItems(at: offsets, from: pastExams)
    }
    
    func deleteItems(at offsets: IndexSet, from list: [ExamResult]) {
        for index in offsets {
            let exam = list[index]
            guard let id = exam.id else { return }
            Task {
                try? await lessonManager.deleteExamResult(id: id)
                await fetchData()
            }
        }
    }
}

struct ExamRow: View {
    let exam: ExamResult
    var showStudentName: Bool = false
    @EnvironmentObject var dataService: DataService
    @State private var studentName: String?
    
    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(exam.status == .completed ? (exam.isPass == true ? Color.accentGreen.opacity(0.15) : Color.warningRed.opacity(0.15)) : Color.indigo.opacity(0.15))
                    .frame(width: 40, height: 40)
                
                Image(systemName: exam.status == .completed ? (exam.isPass == true ? "checkmark" : "xmark") : "calendar")
                    .foregroundColor(exam.status == .completed ? (exam.isPass == true ? .accentGreen : .warningRed) : .indigo)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                if showStudentName {
                    Text(studentName ?? "Loading...").font(.headline)
                    Text(exam.testCenter).font(.subheadline).foregroundColor(.secondary)
                } else {
                    Text(exam.testCenter).font(.headline)
                }
                
                Text(exam.date.formatted(date: .abbreviated, time: .shortened)).font(.caption).foregroundColor(.secondary)
            }
            
            Spacer()
            
            if exam.status == .completed {
                if exam.isPass == true {
                    VStack(alignment: .trailing) {
                        Text("PASS").font(.caption).bold().foregroundColor(.accentGreen)
                        Text("\(exam.minorFaults ?? 0) Minors").font(.caption2).foregroundColor(.secondary)
                    }
                } else {
                    VStack(alignment: .trailing) {
                        Text("FAIL").font(.caption).bold().foregroundColor(.warningRed)
                        Text("Majors: \(exam.seriousFaults ?? 0)").font(.caption2).foregroundColor(.secondary)
                    }
                }
            } else {
                Text("Scheduled").font(.caption).padding(6).background(Color.secondaryGray).cornerRadius(8)
            }
        }
        .task {
            if showStudentName && studentName == nil {
                self.studentName = await dataService.resolveStudentName(studentID: exam.studentID)
            }
        }
    }
}
