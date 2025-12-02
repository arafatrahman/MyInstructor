// File: arafatrahman/myinstructor/MyInstructor-main/MyInstructor/Features/Student/StudentCalendarView.swift
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
    
    private var itemsByDay: [(Date, [CalendarItem])] {
        let grouped = Dictionary(grouping: calendarItems) { item in Calendar.current.startOfDay(for: item.date) }
        return grouped.sorted { $0.key < $1.key }
    }
    
    private var startOfWeek: Date {
        Calendar.current.date(from: Calendar.current.dateComponents([.yearForWeekOfYear, .weekOfYear], from: selectedDate)) ?? selectedDate
    }

    var body: some View {
        NavigationView {
            ZStack {
                Color(.systemGroupedBackground).ignoresSafeArea()
                
                VStack(spacing: 0) {
                    ModernWeekHeader(selectedDate: $selectedDate)
                        .background(Color(.systemBackground))
                        .shadow(color: Color.black.opacity(0.05), radius: 5, y: 5)
                        .zIndex(1)
                    
                    if isLoading {
                        Spacer(); ProgressView("Loading Your Schedule..."); Spacer()
                    } else if calendarItems.isEmpty {
                        EmptyStateView(icon: "calendar", message: "No lessons or events scheduled.", actionTitle: "Add Event", action: { isAddPersonalSheetPresented = true })
                    } else {
                        ScrollView {
                            LazyVStack(spacing: 20) {
                                ForEach(itemsByDay, id: \.0) { (date, dailyItems) in
                                    DaySectionView(
                                        date: date,
                                        items: dailyItems,
                                        onSelectService: { _ in },
                                        onSelectPersonal: { event in self.personalEventToEdit = event }
                                    )
                                }
                            }.padding(.vertical, 20)
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
            .sheet(isPresented: $isShowingStats) {
                if let studentID = authManager.user?.id { StudentLessonStatsView(studentID: studentID) }
            }
            .sheet(isPresented: $isAddPersonalSheetPresented) { AddPersonalEventView(onSave: { Task { await fetchStudentCalendarData() } }) }
            .sheet(item: $personalEventToEdit) { event in AddPersonalEventView(eventToEdit: event, onSave: { personalEventToEdit = nil; Task { await fetchStudentCalendarData() } }) }
        }
    }
    
    private func fetchStudentCalendarData() async {
        guard let studentID = authManager.user?.id else { return }
        isLoading = true
        let start = startOfWeek
        let end = Calendar.current.date(byAdding: .day, value: 7, to: start) ?? Date()
        
        do {
            async let lessonsTask = lessonManager.fetchLessonsForStudent(studentID: studentID, start: start, end: end)
            async let personalTask = personalEventManager.fetchEvents(for: studentID, start: start, end: end)
            
            let fetchedLessons = try await lessonsTask
            let fetchedPersonal = try await personalTask
            
            let lessonItems = fetchedLessons.map { CalendarItem(id: $0.id ?? UUID().uuidString, date: $0.startTime, type: .lesson($0)) }
            let personalItems = fetchedPersonal.map { CalendarItem(id: $0.id ?? UUID().uuidString, date: $0.date, type: .personal($0)) }
            
            self.calendarItems = (lessonItems + personalItems).sorted(by: { $0.date < $1.date })
        } catch { print("Error fetching student calendar: \(error)") }
        isLoading = false
    }
}
