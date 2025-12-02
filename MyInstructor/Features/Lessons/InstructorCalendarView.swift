// File: arafatrahman/myinstructor/MyInstructor-main/MyInstructor/Features/Lessons/InstructorCalendarView.swift
import SwiftUI

struct InstructorCalendarView: View {
    @EnvironmentObject var lessonManager: LessonManager
    @EnvironmentObject var dataService: DataService
    @EnvironmentObject var authManager: AuthManager
    @EnvironmentObject var vehicleManager: VehicleManager
    @EnvironmentObject var personalEventManager: PersonalEventManager
    
    @State private var selectedDate: Date = Date()
    @State private var calendarItems: [CalendarItem] = []
    
    @State private var isAddLessonSheetPresented = false
    @State private var isAddPersonalSheetPresented = false
    
    @State private var serviceToEdit: ServiceRecord? = nil
    @State private var personalEventToEdit: PersonalEvent? = nil
    
    @State private var isLoading = false
    
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
                        Spacer(); ProgressView("Loading Schedule..."); Spacer()
                    } else if calendarItems.isEmpty {
                        EmptyStateView(icon: "calendar.badge.plus", message: "No events scheduled for this week.", actionTitle: "Add Event", action: { isAddLessonSheetPresented = true })
                    } else {
                        ScrollView {
                            LazyVStack(spacing: 20) {
                                ForEach(itemsByDay, id: \.0) { (date, dailyItems) in
                                    DaySectionView(
                                        date: date,
                                        items: dailyItems,
                                        onSelectService: { service in self.serviceToEdit = service },
                                        onSelectPersonal: { event in self.personalEventToEdit = event }
                                    )
                                }
                            }.padding(.vertical, 20)
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
            .sheet(isPresented: $isAddLessonSheetPresented) { AddLessonFormView(onLessonAdded: { _ in Task { await fetchCalendarData() } }) }
            .sheet(isPresented: $isAddPersonalSheetPresented) { AddPersonalEventView(onSave: { Task { await fetchCalendarData() } }) }
            .sheet(item: $serviceToEdit) { service in AddServiceRecordView(recordToEdit: service, onSave: { serviceToEdit = nil; Task { await fetchCalendarData() } }) }
            .sheet(item: $personalEventToEdit) { event in AddPersonalEventView(eventToEdit: event, onSave: { personalEventToEdit = nil; Task { await fetchCalendarData() } }) }
        }
    }
    
    private func fetchCalendarData() async {
        guard let instructorID = authManager.user?.id else { return }
        isLoading = true
        let start = startOfWeek
        let end = Calendar.current.date(byAdding: .day, value: 7, to: start) ?? Date()
        
        do {
            async let lessonsTask = lessonManager.fetchLessons(for: instructorID, start: start, end: end)
            async let servicesTask = vehicleManager.fetchServiceRecords(for: instructorID)
            async let personalTask = personalEventManager.fetchEvents(for: instructorID, start: start, end: end)
            
            let lessons = try await lessonsTask
            let services = try await servicesTask
            let personalEvents = try await personalTask
            
            let lessonItems = lessons.map { CalendarItem(id: $0.id ?? UUID().uuidString, date: $0.startTime, type: .lesson($0)) }
            let serviceItems = services.filter { $0.date >= start && $0.date < end }.map { CalendarItem(id: $0.id ?? UUID().uuidString, date: $0.date, type: .service($0)) }
            let personalItems = personalEvents.map { CalendarItem(id: $0.id ?? UUID().uuidString, date: $0.date, type: .personal($0)) }
            
            self.calendarItems = (lessonItems + serviceItems + personalItems).sorted(by: { $0.date < $1.date })
        } catch { print("Error fetching calendar data: \(error)") }
        isLoading = false
    }
}
