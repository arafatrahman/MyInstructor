// File: arafatrahman/myinstructor/MyInstructor-main/MyInstructor/Features/Lessons/InstructorCalendarView.swift
// --- UPDATED: Lessons now navigate to Details View; improved click handling ---

import SwiftUI

struct InstructorCalendarView: View {
    @EnvironmentObject var lessonManager: LessonManager
    @EnvironmentObject var dataService: DataService
    @EnvironmentObject var authManager: AuthManager
    @EnvironmentObject var vehicleManager: VehicleManager
    @EnvironmentObject var personalEventManager: PersonalEventManager
    
    @State private var selectedDate: Date = Date()
    @State private var calendarItems: [CalendarItem] = []
    
    // --- Navigation State ---
    @State private var selectedLesson: Lesson? = nil // For navigation to details
    
    // --- Sheet States ---
    @State private var isAddLessonSheetPresented = false
    @State private var isAddPersonalSheetPresented = false
    
    @State private var serviceToEdit: ServiceRecord? = nil
    @State private var personalEventToEdit: PersonalEvent? = nil
    @State private var examToEdit: ExamResult? = nil
    
    @State private var isLoading = false
    
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
                
                // --- INVISIBLE NAVIGATION LINK FOR LESSON DETAILS ---
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
                        Spacer(); ProgressView("Loading Schedule..."); Spacer()
                    } else {
                        ScrollView {
                            LazyVStack(spacing: 20) {
                                DaySectionView(
                                    date: selectedDate,
                                    items: selectedDayItems,
                                    onSelectLesson: { lesson in self.selectedLesson = lesson }, // Navigates to details
                                    onSelectService: { service in self.serviceToEdit = service },
                                    onSelectPersonal: { event in self.personalEventToEdit = event },
                                    onSelectExam: { exam in self.examToEdit = exam }
                                )
                            }
                            .padding(.vertical, 20)
                        }
                    }
                }
            }
            .navigationTitle("Calendar")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Today") { withAnimation { selectedDate = Date() } }.font(.subheadline)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button { isAddLessonSheetPresented = true } label: { Label("Add Lesson", systemImage: "steeringwheel") }
                        Button { isAddPersonalSheetPresented = true } label: { Label("Add Personal Event", systemImage: "person.circle") }
                    } label: {
                        Image(systemName: "plus.circle.fill").font(.title2).foregroundColor(.primaryBlue).shadow(radius: 1)
                    }
                }
            }
            .onAppear { Task { await fetchCalendarData() } }
            .onChange(of: selectedDate) { _, _ in Task { await fetchCalendarData() } }
            
            // --- Sheets ---
            .sheet(isPresented: $isAddLessonSheetPresented) {
                AddLessonFormView(onLessonAdded: { _ in Task { await fetchCalendarData() } })
            }
            .sheet(isPresented: $isAddPersonalSheetPresented) {
                AddPersonalEventView(onSave: { Task { await fetchCalendarData() } })
            }
            
            // Edit Sheets (For items other than Lessons)
            .sheet(item: $examToEdit) { exam in
                AddExamFormView(studentID: exam.studentID, examToEdit: exam, onSave: { Task { await fetchCalendarData() } })
            }
            .sheet(item: $serviceToEdit) { service in
                AddServiceRecordView(recordToEdit: service, onSave: { serviceToEdit = nil; Task { await fetchCalendarData() } })
            }
            .sheet(item: $personalEventToEdit) { event in
                AddPersonalEventView(eventToEdit: event, onSave: { personalEventToEdit = nil; Task { await fetchCalendarData() } })
            }
        }
    }
    
    private func fetchCalendarData() async {
        guard let instructorID = authManager.user?.id else { return }
        
        let calendar = Calendar.current
        guard let startOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: selectedDate)),
              let _ = calendar.date(byAdding: .month, value: 1, to: startOfMonth) else { return }
        
        guard let startFetch = calendar.date(byAdding: .month, value: -1, to: startOfMonth),
              let endFetch = calendar.date(byAdding: .month, value: 2, to: startOfMonth) else { return }
        
        if calendarItems.isEmpty { isLoading = true }
        
        do {
            async let lessonsTask = lessonManager.fetchLessons(for: instructorID, start: startFetch, end: endFetch)
            async let servicesTask = vehicleManager.fetchServiceRecords(for: instructorID)
            async let personalTask = personalEventManager.fetchEvents(for: instructorID, start: startFetch, end: endFetch)
            async let examsTask = lessonManager.fetchExamsForInstructor(instructorID: instructorID)
            
            let lessons = try await lessonsTask
            let services = try await servicesTask
            let personalEvents = try await personalTask
            let exams = try await examsTask
            
            let lessonItems = lessons.map { CalendarItem(id: $0.id ?? UUID().uuidString, date: $0.startTime, type: .lesson($0)) }
            let serviceItems = services.filter { $0.date >= startFetch && $0.date < endFetch }.map { CalendarItem(id: $0.id ?? UUID().uuidString, date: $0.date, type: .service($0)) }
            let personalItems = personalEvents.map { CalendarItem(id: $0.id ?? UUID().uuidString, date: $0.date, type: .personal($0)) }
            let examItems = exams.filter { $0.date >= startFetch && $0.date < endFetch }.map { CalendarItem(id: $0.id ?? UUID().uuidString, date: $0.date, type: .exam($0)) }
            
            self.calendarItems = (lessonItems + serviceItems + personalItems + examItems).sorted(by: { $0.date < $1.date })
        } catch { print("Error fetching calendar data: \(error)") }
        isLoading = false
    }
}
