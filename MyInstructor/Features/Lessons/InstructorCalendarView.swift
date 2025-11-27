// File: arafatrahman/myinstructor/MyInstructor-main/MyInstructor/Features/Lessons/InstructorCalendarView.swift
// --- UPDATED: Service cards are now tappable and editable ---

import SwiftUI

// Wrapper to handle different event types in the same list
enum CalendarItemType {
    case lesson(Lesson)
    case service(ServiceRecord)
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
    
    @State private var selectedDate: Date = Date()
    @State private var calendarItems: [CalendarItem] = []
    
    @State private var isAddLessonSheetPresented = false
    // --- NEW: State for editing service record ---
    @State private var serviceToEdit: ServiceRecord? = nil
    
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
                            message: "No lessons or services scheduled for this week.",
                            actionTitle: "Add Lesson",
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
                                            // Trigger edit sheet
                                            self.serviceToEdit = service
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
                    Button {
                        isAddLessonSheetPresented = true
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
            // --- NEW: Sheet for Editing Service ---
            .sheet(item: $serviceToEdit) { service in
                AddServiceRecordView(recordToEdit: service, onSave: {
                    serviceToEdit = nil
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
            let fetchedLessons = try await lessonManager.fetchLessons(for: instructorID, start: start, end: end)
            let lessonItems = fetchedLessons.map { CalendarItem(id: $0.id ?? UUID().uuidString, date: $0.startTime, type: .lesson($0)) }
            
            // 2. Fetch Service Records
            let allServices = try await vehicleManager.fetchServiceRecords(for: instructorID)
            let filteredServices = allServices.filter { record in
                return record.date >= start && record.date < end
            }
            let serviceItems = filteredServices.map { CalendarItem(id: $0.id ?? UUID().uuidString, date: $0.date, type: .service($0)) }
            
            // 3. Merge and Sort
            self.calendarItems = (lessonItems + serviceItems).sorted(by: { $0.date < $1.date })
            
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
    let onSelectService: (ServiceRecord) -> Void // Callback for service selection
    
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
                    // Wrap Service Card in Button
                    Button {
                        onSelectService(service)
                    } label: {
                        ServiceEventCard(service: service)
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal)
                }
            }
        }
    }
}

struct ServiceEventCard: View {
    let service: ServiceRecord
    
    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            // Left: Icon Strip
            VStack(alignment: .center, spacing: 6) {
                Image(systemName: "wrench.and.screwdriver.fill")
                    .font(.title2)
                    .foregroundColor(.gray)
                
                Text("Service")
                    .font(.system(size: 10, weight: .bold))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(Color.gray.opacity(0.15))
                    .foregroundColor(.gray)
                    .cornerRadius(4)
            }
            .frame(width: 75)
            .padding(.vertical, 16)
            
            // Vertical Divider
            Rectangle()
                .fill(Color.secondaryGray)
                .frame(width: 1)
                .padding(.vertical, 10)
            
            // Right: Content
            VStack(alignment: .leading, spacing: 6) {
                Text(service.serviceType)
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Text(service.garageName)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                if let nextDate = service.nextServiceDate {
                    HStack(spacing: 4) {
                        Image(systemName: "calendar.badge.clock")
                        Text("Next due: \(nextDate.formatted(date: .abbreviated, time: .omitted))")
                    }
                    .font(.caption)
                    .foregroundColor(.orange)
                }
            }
            .padding(16)
            
            Spacer()
            
            // Chevron to indicate tap-ability
            Image(systemName: "chevron.right")
                .foregroundColor(.secondary.opacity(0.3))
                .padding(.trailing, 16)
                .padding(.top, 40)
        }
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.05), radius: 4, x: 0, y: 2)
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
            if let user = try? await dataService.fetchUser(withId: lesson.studentID) {
                self.studentName = user.name ?? "Unknown Student"
            } else {
                self.studentName = "Student"
            }
        }
    }
}
