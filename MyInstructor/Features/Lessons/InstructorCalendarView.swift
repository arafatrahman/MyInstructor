// File: arafatrahman/myinstructor/MyInstructor-main/MyInstructor/Features/Lessons/InstructorCalendarView.swift
// --- UPDATED: Added support for Personal Events ---

import SwiftUI

// Wrapper to handle different event types in the same list
enum CalendarItemType {
    case lesson(Lesson)
    case service(ServiceRecord)
    case personal(PersonalEvent) // <--- ADDED
}

struct CalendarItem: Identifiable {
    let id: String
    let date: Date
    let type: CalendarItemType
}

// Flow Item 7: Instructor Calendar View
struct InstructorCalendarView: View {
    @EnvironmentObject var lessonManager: LessonManager
    @EnvironmentObject var dataService: DataService
    @EnvironmentObject var authManager: AuthManager
    @EnvironmentObject var vehicleManager: VehicleManager
    @EnvironmentObject var personalEventManager: PersonalEventManager // <--- ADDED
    
    @State private var selectedDate: Date = Date()
    @State private var calendarItems: [CalendarItem] = []
    
    // Sheets
    @State private var isAddLessonSheetPresented = false
    @State private var isAddPersonalSheetPresented = false // <--- ADDED
    
    // Editing States
    @State private var serviceToEdit: ServiceRecord? = nil
    @State private var personalEventToEdit: PersonalEvent? = nil // <--- ADDED
    
    @State private var isLoading = false
    
    // Computed property: Group items by the start of the day
    private var itemsByDay: [(Date, [CalendarItem])] {
        let grouped = Dictionary(grouping: calendarItems) { item in
            Calendar.current.startOfDay(for: item.date)
        }
        return grouped.sorted { $0.key < $1.key }
    }
    
    // Calculate the start of the week
    private var startOfWeek: Date {
        Calendar.current.date(from: Calendar.current.dateComponents([.yearForWeekOfYear, .weekOfYear], from: selectedDate)) ?? selectedDate
    }

    var body: some View {
        NavigationView {
            ZStack {
                Color(.systemGroupedBackground)
                    .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // MARK: - Modern Week Picker
                    ModernWeekHeader(selectedDate: $selectedDate)
                        .background(Color(.systemBackground))
                        .shadow(color: Color.black.opacity(0.05), radius: 5, y: 5)
                        .zIndex(1)
                    
                    if isLoading {
                        Spacer()
                        ProgressView("Loading Schedule...")
                        Spacer()
                    } else if calendarItems.isEmpty {
                        EmptyStateView(
                            icon: "calendar.badge.plus",
                            message: "No events scheduled for this week.",
                            actionTitle: "Add Event",
                            action: { isAddLessonSheetPresented = true }
                        )
                    } else {
                        // MARK: - Timeline Scroll View
                        ScrollView {
                            LazyVStack(spacing: 20) {
                                ForEach(itemsByDay, id: \.0) { (date, dailyItems) in
                                    DaySectionView(
                                        date: date,
                                        items: dailyItems,
                                        onSelectService: { service in
                                            self.serviceToEdit = service
                                        },
                                        onSelectPersonal: { event in // <--- ADDED
                                            self.personalEventToEdit = event
                                        }
                                    )
                                }
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
                    Button("Today") {
                        withAnimation {
                            selectedDate = Date()
                        }
                    }
                    .font(.subheadline)
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    // Replaced simple button with Menu to choose event type
                    Menu {
                        Button {
                            isAddLessonSheetPresented = true
                        } label: {
                            Label("Add Lesson", systemImage: "steeringwheel")
                        }
                        
                        Button {
                            isAddPersonalSheetPresented = true
                        } label: {
                            Label("Add Personal Event", systemImage: "person.circle")
                        }
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.title2)
                            .foregroundColor(.primaryBlue)
                            .shadow(radius: 1)
                    }
                }
            }
            .onAppear {
                Task { await fetchCalendarData() }
            }
            .onChange(of: selectedDate) { _, _ in
                Task { await fetchCalendarData() }
            }
            // Sheet for Adding Lessons
            .sheet(isPresented: $isAddLessonSheetPresented) {
                AddLessonFormView(onLessonAdded: { _ in
                    Task { await fetchCalendarData() }
                })
            }
            // Sheet for Adding Personal Events
            .sheet(isPresented: $isAddPersonalSheetPresented) {
                AddPersonalEventView(onSave: {
                    Task { await fetchCalendarData() }
                })
            }
            // Sheet for Editing Service
            .sheet(item: $serviceToEdit) { service in
                AddServiceRecordView(recordToEdit: service, onSave: {
                    serviceToEdit = nil
                    Task { await fetchCalendarData() }
                })
            }
            // Sheet for Editing Personal Event
            .sheet(item: $personalEventToEdit) { event in
                AddPersonalEventView(eventToEdit: event, onSave: {
                    personalEventToEdit = nil
                    Task { await fetchCalendarData() }
                })
            }
        }
    }
    
    private func fetchCalendarData() async {
        guard let instructorID = authManager.user?.id else { return }
        
        isLoading = true
        let start = startOfWeek
        let end = Calendar.current.date(byAdding: .day, value: 7, to: start) ?? Date()
        
        do {
            // 1. Fetch Lessons
            async let lessonsTask = lessonManager.fetchLessons(for: instructorID, start: start, end: end)
            // 2. Fetch Service Records
            async let servicesTask = vehicleManager.fetchServiceRecords(for: instructorID)
            // 3. Fetch Personal Events
            async let personalTask = personalEventManager.fetchEvents(for: instructorID, start: start, end: end)
            
            let lessons = try await lessonsTask
            let services = try await servicesTask
            let personalEvents = try await personalTask
            
            let lessonItems = lessons.map { CalendarItem(id: $0.id ?? UUID().uuidString, date: $0.startTime, type: .lesson($0)) }
            
            let serviceItems = services
                .filter { $0.date >= start && $0.date < end }
                .map { CalendarItem(id: $0.id ?? UUID().uuidString, date: $0.date, type: .service($0)) }
            
            let personalItems = personalEvents.map { CalendarItem(id: $0.id ?? UUID().uuidString, date: $0.date, type: .personal($0)) }
            
            // 4. Merge and Sort
            self.calendarItems = (lessonItems + serviceItems + personalItems).sorted(by: { $0.date < $1.date })
            
        } catch {
            print("Error fetching calendar data: \(error)")
        }
        isLoading = false
    }
}

// MARK: - Subviews

struct ModernWeekHeader: View {
    @Binding var selectedDate: Date
    private let calendar = Calendar.current
    
    var weekRangeString: String {
        let start = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: selectedDate)) ?? selectedDate
        let end = calendar.date(byAdding: .day, value: 6, to: start) ?? start
        
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        return "\(formatter.string(from: start)) – \(formatter.string(from: end))"
    }
    
    var body: some View {
        HStack {
            Button {
                withAnimation {
                    selectedDate = calendar.date(byAdding: .weekOfYear, value: -1, to: selectedDate) ?? selectedDate
                }
            } label: {
                Image(systemName: "chevron.left.circle.fill")
                    .font(.title3)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            VStack(spacing: 2) {
                Text(weekRangeString)
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Text(calendar.component(.year, from: selectedDate).description.replacingOccurrences(of: ",", with: ""))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Button {
                withAnimation {
                    selectedDate = calendar.date(byAdding: .weekOfYear, value: 1, to: selectedDate) ?? selectedDate
                }
            } label: {
                Image(systemName: "chevron.right.circle.fill")
                    .font(.title3)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
    }
}

struct DaySectionView: View {
    let date: Date
    let items: [CalendarItem]
    let onSelectService: (ServiceRecord) -> Void
    let onSelectPersonal: (PersonalEvent) -> Void // <--- ADDED Callback
    
    var isToday: Bool {
        Calendar.current.isDateInToday(date)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Day Header
            HStack {
                Text(date.formatted(.dateTime.weekday(.wide)))
                    .font(.title3).bold()
                    .foregroundColor(isToday ? .primaryBlue : .primary)
                
                Text(date.formatted(.dateTime.month().day()))
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                if isToday {
                    Text("TODAY")
                        .font(.caption).bold()
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.primaryBlue.opacity(0.1))
                        .foregroundColor(.primaryBlue)
                        .cornerRadius(4)
                }
                
                Spacer()
            }
            .padding(.horizontal)
            
            // Items List
            ForEach(items) { item in
                switch item.type {
                case .lesson(let lesson):
                    ModernLessonCard(lesson: lesson)
                        .padding(.horizontal)
                case .service(let service):
                    Button {
                        onSelectService(service)
                    } label: {
                        ServiceEventCard(service: service)
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal)
                case .personal(let event): // <--- ADDED Personal Card
                    Button {
                        onSelectPersonal(event)
                    } label: {
                        PersonalEventCard(event: event)
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal)
                }
            }
        }
    }
}

// --- ADDED: Personal Event Card UI ---
struct PersonalEventCard: View {
    let event: PersonalEvent
    @EnvironmentObject var personalEventManager: PersonalEventManager
    
    // Format duration nicely
    private var durationString: String {
        let hours = event.duration / 3600.0
        return String(format: "%.1f h", hours)
    }
    
    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            // Left Strip
            VStack(alignment: .center, spacing: 6) {
                Text(event.date, style: .time)
                    .font(.subheadline).bold()
                    .foregroundColor(.primary)
                    .multilineTextAlignment(.center)
                
                Text(durationString)
                    .font(.caption2).bold()
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.purple.opacity(0.15))
                    .foregroundColor(.purple)
                    .cornerRadius(4)
            }
            .frame(width: 75)
            .padding(.vertical, 16)
            
            // Divider
            Rectangle().fill(Color.secondaryGray).frame(width: 1).padding(.vertical, 10)
            
            // Content
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(event.title)
                        .font(.headline)
                        .foregroundColor(.primary)
                    Spacer()
                    Image(systemName: "person.circle.fill")
                        .foregroundColor(.purple)
                }
                
                if let notes = event.notes, !notes.isEmpty {
                    Text(notes)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                } else {
                    Text("Personal Time")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .padding(16)
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .foregroundColor(.secondary.opacity(0.3))
                .padding(.trailing, 16)
                .padding(.top, 30)
        }
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.05), radius: 4, x: 0, y: 2)
        // Swipe to delete for personal events
        .swipeActions(edge: .trailing) {
            Button(role: .destructive) {
                Task { try? await personalEventManager.deleteEvent(id: event.id ?? "") }
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
    }
}

// ServiceEventCard and ModernLessonCard remain unchanged...
struct ServiceEventCard: View {
    let service: ServiceRecord
    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            VStack(alignment: .center, spacing: 6) {
                Image(systemName: "wrench.and.screwdriver.fill").font(.title2).foregroundColor(.gray)
                Text("Service").font(.system(size: 10, weight: .bold)).padding(.horizontal, 6).padding(.vertical, 3).background(Color.gray.opacity(0.15)).foregroundColor(.gray).cornerRadius(4)
            }.frame(width: 75).padding(.vertical, 16)
            Rectangle().fill(Color.secondaryGray).frame(width: 1).padding(.vertical, 10)
            VStack(alignment: .leading, spacing: 6) {
                Text(service.serviceType).font(.headline).foregroundColor(.primary)
                Text(service.garageName).font(.subheadline).foregroundColor(.secondary)
                if let nextDate = service.nextServiceDate {
                    HStack(spacing: 4) { Image(systemName: "calendar.badge.clock"); Text("Next due: \(nextDate.formatted(date: .abbreviated, time: .omitted))") }.font(.caption).foregroundColor(.orange)
                }
            }.padding(16)
            Spacer()
            Image(systemName: "chevron.right").foregroundColor(.secondary.opacity(0.3)).padding(.trailing, 16).padding(.top, 40)
        }.background(Color(.secondarySystemGroupedBackground)).cornerRadius(12).shadow(color: Color.black.opacity(0.05), radius: 4, x: 0, y: 2)
    }
}

struct ModernLessonCard: View {
    @EnvironmentObject var dataService: DataService
    let lesson: Lesson
    @State private var studentName: String = "Loading..."
    private var statusConfig: (text: String, color: Color) {
        switch lesson.status {
        case .completed: return ("Finished", .accentGreen)
        case .cancelled: return ("Cancelled", .warningRed)
        case .scheduled:
            let now = Date()
            let endTime = lesson.startTime.addingTimeInterval(lesson.duration ?? 3600)
            if endTime < now { return ("Pending", .orange) }
            else if lesson.startTime <= now && endTime >= now { return ("Active", .primaryBlue) }
            else if lesson.startTime > now && lesson.startTime.timeIntervalSince(now) < 3600 { return ("Up Next", .primaryBlue) }
            else { return ("Booked", .secondary) }
        }
    }
    var body: some View {
        NavigationLink(destination: LessonDetailsView(lesson: lesson)) {
            HStack(alignment: .top, spacing: 0) {
                VStack(alignment: .center, spacing: 6) {
                    Text(lesson.startTime, style: .time).font(.subheadline).bold().foregroundColor(.primary).multilineTextAlignment(.center)
                    Text(lesson.duration?.formattedDuration() ?? "1h").font(.caption2).bold().padding(.horizontal, 6).padding(.vertical, 2).background(Color.secondaryGray).foregroundColor(.secondary).cornerRadius(4)
                    Text(statusConfig.text).font(.system(size: 9, weight: .bold)).padding(.horizontal, 6).padding(.vertical, 3).background(statusConfig.color.opacity(0.15)).foregroundColor(statusConfig.color).cornerRadius(4).lineLimit(1).fixedSize(horizontal: true, vertical: false)
                }
                .frame(width: 75).padding(.vertical, 16)
                Rectangle().fill(Color.secondaryGray).frame(width: 1).padding(.vertical, 10)
                VStack(alignment: .leading, spacing: 6) {
                    Text(lesson.topic).font(.headline).foregroundColor(.primary).lineLimit(1)
                    HStack(spacing: 6) { Image(systemName: "person.fill").font(.caption).foregroundColor(.primaryBlue); Text(studentName).font(.subheadline).foregroundColor(.secondary).lineLimit(1) }
                    HStack(spacing: 6) { Image(systemName: "mappin.and.ellipse").font(.caption).foregroundColor(.orange); Text(lesson.pickupLocation).font(.caption).foregroundColor(.secondary).lineLimit(1) }
                }.padding(16)
                Spacer()
                Image(systemName: "chevron.right").foregroundColor(.secondary.opacity(0.3)).padding(.trailing, 16).padding(.top, 40)
            }
            .background(Color(.secondarySystemGroupedBackground)).cornerRadius(12).shadow(color: Color.black.opacity(0.05), radius: 4, x: 0, y: 2)
        }
        .buttonStyle(.plain)
        .task {
            if let user = try? await dataService.fetchUser(withId: lesson.studentID) { self.studentName = user.name ?? "Unknown Student" }
            else { self.studentName = "Student" }
        }
    }
}
