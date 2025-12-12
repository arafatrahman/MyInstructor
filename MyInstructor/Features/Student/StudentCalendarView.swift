// File: arafatrahman/myinstructor/MyInstructor-main/MyInstructor/Features/Student/StudentCalendarView.swift
// --- UPDATED: Handles Lesson and Exam clicks ---

import SwiftUI

struct StudentCalendarView: View {
    @EnvironmentObject var lessonManager: LessonManager
    @EnvironmentObject var authManager: AuthManager
    @EnvironmentObject var personalEventManager: PersonalEventManager
    
    @State private var selectedDate: Date = Date()
    @State private var calendarItems: [CalendarItem] = []
    @State private var isLoading = false
    
    @State private var isShowingStats = false
    @State private var isAddPersonalSheetPresented = false
    @State private var personalEventToEdit: PersonalEvent? = nil
    
    // --- Selection States ---
    @State private var selectedLesson: Lesson? = nil
    @State private var selectedExam: ExamResult? = nil
    
    private var eventDates: Set<DateComponents> {
        let components = calendarItems.map { Calendar.current.dateComponents([.year, .month, .day], from: $0.date) }
        return Set(components)
    }
    
    private var selectedDayItems: [CalendarItem] {
        calendarItems.filter { Calendar.current.isDate($0.date, inSameDayAs: selectedDate) }
            .sorted { $0.date < $1.date }
    }

    var body: some View {
        NavigationView {
            ZStack {
                Color(.systemGroupedBackground).ignoresSafeArea()
                
                // Invisible Navigation Link for Lesson Details
                if let lesson = selectedLesson {
                    NavigationLink(destination: LessonDetailsView(lesson: lesson), isActive: Binding(
                        get: { selectedLesson != nil },
                        set: { if !$0 { selectedLesson = nil } }
                    )) { EmptyView() }
                }
                
                VStack(spacing: 0) {
                    CustomMonthlyCalendar(selectedDate: $selectedDate, eventDates: eventDates)
                        .padding(.horizontal)
                        .padding(.top, 10)
                        .zIndex(1)
                    
                    if isLoading {
                        Spacer(); ProgressView("Loading Your Schedule..."); Spacer()
                    } else if selectedDayItems.isEmpty {
                        Spacer()
                        EmptyStateView(
                            icon: "calendar",
                            message: "No lessons on \(selectedDate.formatted(.dateTime.day().month()))",
                            actionTitle: "Add Event",
                            action: { isAddPersonalSheetPresented = true }
                        )
                        Spacer()
                    } else {
                        ScrollView {
                            LazyVStack(spacing: 20) {
                                DaySectionView(
                                    date: selectedDate,
                                    items: selectedDayItems,
                                    onSelectLesson: { lesson in self.selectedLesson = lesson },
                                    onSelectService: { _ in },
                                    onSelectPersonal: { event in self.personalEventToEdit = event },
                                    onSelectExam: { exam in self.selectedExam = exam }
                                )
                            }
                            .padding(.vertical, 20)
                        }
                    }
                }
            }
            .navigationTitle("My Schedule")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Today") { withAnimation { selectedDate = Date() } }.font(.subheadline)
                }
                ToolbarItem(placement: .primaryAction) {
                    HStack(spacing: 15) {
                        Button { isAddPersonalSheetPresented = true } label: { Image(systemName: "plus.circle").font(.headline) }
                        Button { isShowingStats = true } label: { Image(systemName: "chart.bar.doc.horizontal.fill").font(.headline) }
                    }
                }
            }
            .onAppear { Task { await fetchStudentCalendarData() } }
            .onChange(of: selectedDate) { _, _ in Task { await fetchStudentCalendarData() } }
            
            .sheet(isPresented: $isShowingStats) { if let studentID = authManager.user?.id { StudentLessonStatsView(studentID: studentID) } }
            .sheet(isPresented: $isAddPersonalSheetPresented) { AddPersonalEventView(onSave: { Task { await fetchStudentCalendarData() } }) }
            .sheet(item: $personalEventToEdit) { event in AddPersonalEventView(eventToEdit: event, onSave: { personalEventToEdit = nil; Task { await fetchStudentCalendarData() } }) }
            
            // Sheet for Exam (using the generic Add/Edit form for viewing/updating)
            .sheet(item: $selectedExam) { exam in
                StudentTrackExamView(onSave: {
                    selectedExam = nil
                    Task { await fetchStudentCalendarData() }
                })
                // Note: StudentTrackExamView currently doesn't support 'edit' mode in its init easily based on previous context,
                // so for now this might just open the form. Ideally, we should pass 'examToEdit'.
                // Assuming StudentTrackExamView stays as is (create mode), let's use the generic form that supports editing if possible,
                // or just ExamListView if we want to list.
                // Since user wants to click a schedule item, they probably want to see *that* exam.
                // I'll use AddExamFormView which is more robust for editing/viewing.
                AddExamFormView(studentID: authManager.user?.id, examToEdit: exam, onSave: {
                    selectedExam = nil
                    Task { await fetchStudentCalendarData() }
                })
            }
        }
    }
    
    private func fetchStudentCalendarData() async {
        guard let studentID = authManager.user?.id else { return }
        
        let calendar = Calendar.current
        guard let startOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: selectedDate)),
              let endOfMonth = calendar.date(byAdding: .month, value: 1, to: startOfMonth) else { return }
        
        guard let startFetch = calendar.date(byAdding: .month, value: -1, to: startOfMonth),
              let endFetch = calendar.date(byAdding: .month, value: 2, to: startOfMonth) else { return }
        
        if calendarItems.isEmpty { isLoading = true }
        
        do {
            async let lessonsTask = lessonManager.fetchLessonsForStudent(studentID: studentID, start: startFetch, end: endFetch)
            async let personalTask = personalEventManager.fetchEvents(for: studentID, start: startFetch, end: endFetch)
            async let examsTask = lessonManager.fetchExamResults(for: studentID)
            
            let fetchedLessons = try await lessonsTask
            let fetchedPersonal = try await personalTask
            let fetchedExams = try await examsTask
            
            let lessonItems = fetchedLessons.map { CalendarItem(id: $0.id ?? UUID().uuidString, date: $0.startTime, type: .lesson($0)) }
            let personalItems = fetchedPersonal.map { CalendarItem(id: $0.id ?? UUID().uuidString, date: $0.date, type: .personal($0)) }
            
            let examItems = fetchedExams
                .filter { $0.date >= startFetch && $0.date < endFetch }
                .map { CalendarItem(id: $0.id ?? UUID().uuidString, date: $0.date, type: .exam($0)) }
            
            self.calendarItems = (lessonItems + personalItems + examItems).sorted(by: { $0.date < $1.date })
        } catch { print("Error fetching student calendar: \(error)") }
        isLoading = false
    }
}
