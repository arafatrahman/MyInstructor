// File: arafatrahman/myinstructor/MyInstructor-main/MyInstructor/Features/Lessons/ExamListView.swift
// --- FULLY UPDATED: Added Time Filters & Stats Cards ---

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
    
    // --- Filters ---
    @State private var selectedFilter: AnalyticsFilter = .monthly
    @State private var currentDate: Date = Date()
    @State private var customStartDate: Date = Date().addingTimeInterval(-86400 * 30)
    @State private var customEndDate: Date = Date()
    
    private let calendar = Calendar.current
    
    // --- Computed Properties for Filtering ---
    var filteredExams: [ExamResult] {
        let range = getRange()
        return exams.filter { $0.date >= range.start && $0.date < range.end }
    }
    
    var upcomingCount: Int {
        filteredExams.filter { $0.status == .scheduled }.count
    }
    
    var passCount: Int {
        filteredExams.filter { $0.status == .completed && $0.isPass == true }.count
    }
    
    var failCount: Int {
        filteredExams.filter { $0.status == .completed && $0.isPass == false }.count
    }
    
    var scheduledExams: [ExamResult] {
        filteredExams.filter { $0.status == .scheduled }.sorted(by: { $0.date < $1.date })
    }
    
    var pastExams: [ExamResult] {
        filteredExams.filter { $0.status == .completed }.sorted(by: { $0.date > $1.date })
    }
    
    var dateRangeDisplay: String {
        switch selectedFilter {
        case .daily: return currentDate.formatted(date: .abbreviated, time: .omitted)
        case .weekly:
            guard let start = calendar.dateInterval(of: .weekOfYear, for: currentDate)?.start,
                  let end = calendar.dateInterval(of: .weekOfYear, for: currentDate)?.end.addingTimeInterval(-1) else { return "" }
            return "\(start.formatted(.dateTime.day().month())) - \(end.formatted(.dateTime.day().month()))"
        case .monthly: return currentDate.formatted(.dateTime.month(.wide).year())
        case .yearly: return currentDate.formatted(.dateTime.year())
        case .custom: return "Custom Range"
        }
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // MARK: - Filter Section
                VStack(spacing: 12) {
                    Picker("Filter", selection: $selectedFilter) {
                        ForEach(AnalyticsFilter.allCases) { filter in
                            Text(filter.rawValue).tag(filter)
                        }
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal)
                    
                    if selectedFilter == .custom {
                        HStack {
                            DatePicker("Start", selection: $customStartDate, displayedComponents: .date)
                                .labelsHidden()
                            Text("-")
                            DatePicker("End", selection: $customEndDate, displayedComponents: .date)
                                .labelsHidden()
                        }
                        .padding(.horizontal)
                    } else {
                        HStack {
                            Button { shiftDate(by: -1) } label: {
                                Image(systemName: "chevron.left")
                                    .padding(8)
                                    .background(Color(.systemGray6))
                                    .clipShape(Circle())
                            }
                            
                            Spacer()
                            Text(dateRangeDisplay)
                                .font(.headline)
                            Spacer()
                            
                            Button { shiftDate(by: 1) } label: {
                                Image(systemName: "chevron.right")
                                    .padding(8)
                                    .background(Color(.systemGray6))
                                    .clipShape(Circle())
                            }
                        }
                        .padding(.horizontal)
                    }
                }
                .padding(.top, 10)
                .padding(.bottom, 10)
                .background(Color(.systemGroupedBackground))
                
                // MARK: - Stats Cards
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        AnalyticsStatCard(title: "Upcoming", value: Double(upcomingCount), type: .number, color: .indigo, icon: "calendar.badge.clock")
                            .frame(width: 140)
                        
                        AnalyticsStatCard(title: "Passed", value: Double(passCount), type: .number, color: .accentGreen, icon: "checkmark.seal.fill")
                            .frame(width: 140)
                        
                        AnalyticsStatCard(title: "Failed", value: Double(failCount), type: .number, color: .warningRed, icon: "xmark.circle.fill")
                            .frame(width: 140)
                    }
                    .padding()
                }
                .background(Color(.systemGroupedBackground))
                
                // MARK: - Exam List
                if isLoading {
                    Spacer(); ProgressView("Loading Exams..."); Spacer()
                } else if filteredExams.isEmpty {
                    Spacer()
                    EmptyStateView(
                        icon: "flag.checkered",
                        message: "No exam records found for this period.",
                        actionTitle: "Schedule Exam",
                        action: { isAddSheetPresented = true }
                    )
                    Spacer()
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
    
    // MARK: - Helpers
    
    private func shiftDate(by value: Int) {
        let component: Calendar.Component
        switch selectedFilter {
        case .daily: component = .day
        case .weekly: component = .weekOfYear
        case .monthly: component = .month
        case .yearly: component = .year
        default: component = .day
        }
        if let newDate = calendar.date(byAdding: component, value: value, to: currentDate) {
            currentDate = newDate
        }
    }
    
    private func getRange() -> (start: Date, end: Date) {
        switch selectedFilter {
        case .daily:
            let start = calendar.startOfDay(for: currentDate)
            let end = calendar.date(byAdding: .day, value: 1, to: start)!
            return (start, end)
        case .weekly:
            let interval = calendar.dateInterval(of: .weekOfYear, for: currentDate)!
            return (interval.start, interval.end)
        case .monthly:
            let interval = calendar.dateInterval(of: .month, for: currentDate)!
            return (interval.start, interval.end)
        case .yearly:
            let interval = calendar.dateInterval(of: .year, for: currentDate)!
            return (interval.start, interval.end)
        case .custom:
            return (calendar.startOfDay(for: customStartDate), calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: customEndDate))!)
        }
    }
    
    func fetchData() async {
        isLoading = true
        do {
            if let specificID = studentID {
                self.exams = try await lessonManager.fetchExamResults(for: specificID)
            } else if authManager.role == .instructor, let instructorID = authManager.user?.id {
                self.exams = try await lessonManager.fetchExamsForInstructor(instructorID: instructorID)
            } else if let myID = authManager.user?.id {
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
        guard let currentUserID = authManager.user?.id else { return }
        for index in offsets {
            let exam = list[index]
            guard let id = exam.id else { return }
            Task {
                try? await lessonManager.deleteExamResult(id: id, initiatorID: currentUserID)
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
