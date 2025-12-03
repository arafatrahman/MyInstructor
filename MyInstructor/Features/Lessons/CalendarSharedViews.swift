// File: arafatrahman/myinstructor/MyInstructor-main/MyInstructor/Features/Lessons/CalendarSharedViews.swift
// --- UPDATED: Added .exam case ---

import SwiftUI

// MARK: - Models
enum CalendarItemType {
    case lesson(Lesson)
    case service(ServiceRecord)
    case personal(PersonalEvent)
    case exam(ExamResult) // <--- NEW
}

struct CalendarItem: Identifiable {
    let id: String
    let date: Date
    let type: CalendarItemType
}

// MARK: - Custom Monthly Calendar
struct CustomMonthlyCalendar: View {
    @Binding var selectedDate: Date
    let eventDates: Set<DateComponents>
    
    @State private var currentMonth: Date = Date()
    private let calendar = Calendar.current
    private let daysOfWeek = ["M", "T", "W", "T", "F", "S", "S"]
    private let columns = Array(repeating: GridItem(.flexible()), count: 7)
    
    var body: some View {
        VStack(spacing: 15) {
            HStack {
                Button { changeMonth(by: -1) } label: { Image(systemName: "chevron.left").font(.headline).foregroundColor(.primary) }
                Spacer()
                Text(monthYearString(for: currentMonth)).font(.title3).bold().foregroundColor(.primary)
                Spacer()
                Button { changeMonth(by: 1) } label: { Image(systemName: "chevron.right").font(.headline).foregroundColor(.primary) }
            }
            .padding(.horizontal)
            
            HStack {
                ForEach(daysOfWeek, id: \.self) { day in
                    Text(day).font(.caption2).bold().foregroundColor(.secondary).frame(maxWidth: .infinity)
                }
            }
            
            LazyVGrid(columns: columns, spacing: 10) {
                ForEach(daysInMonth(), id: \.self) { date in
                    if let date = date {
                        DayCell(date: date, isSelected: calendar.isDate(date, inSameDayAs: selectedDate), isToday: calendar.isDateInToday(date), hasEvent: hasEvent(on: date))
                            .onTapGesture { withAnimation { selectedDate = date } }
                    } else {
                        Text("").frame(maxWidth: .infinity, minHeight: 40)
                    }
                }
            }
        }
        .padding().background(Color(.systemBackground)).cornerRadius(16).shadow(color: Color.black.opacity(0.05), radius: 5, y: 5)
        .onAppear { currentMonth = selectedDate }
    }
    
    private func changeMonth(by value: Int) {
        if let newMonth = calendar.date(byAdding: .month, value: value, to: currentMonth) { withAnimation { currentMonth = newMonth } }
    }
    
    private func monthYearString(for date: Date) -> String {
        let formatter = DateFormatter(); formatter.dateFormat = "MMMM yyyy"; return formatter.string(from: date)
    }
    
    private func daysInMonth() -> [Date?] {
        guard let monthInterval = calendar.dateInterval(of: .month, for: currentMonth), let firstDay = monthInterval.start as Date? else { return [] }
        let daysCount = calendar.range(of: .day, in: .month, for: currentMonth)?.count ?? 0
        let firstWeekday = calendar.component(.weekday, from: firstDay)
        let offset = (firstWeekday + 5) % 7
        var days: [Date?] = Array(repeating: nil, count: offset)
        for i in 0..<daysCount { if let d = calendar.date(byAdding: .day, value: i, to: firstDay) { days.append(d) } }
        return days
    }
    
    private func hasEvent(on date: Date) -> Bool {
        let components = calendar.dateComponents([.year, .month, .day], from: date)
        return eventDates.contains(components)
    }
}

struct DayCell: View {
    let date: Date; let isSelected: Bool; let isToday: Bool; let hasEvent: Bool
    var body: some View {
        VStack(spacing: 4) {
            Text(date.formatted(.dateTime.day())).font(.subheadline).fontWeight(isSelected || isToday ? .bold : .regular)
                .foregroundColor(isSelected ? .white : (isToday ? .primaryBlue : .primary))
                .frame(width: 32, height: 32)
                .background(ZStack { if isSelected { Circle().fill(Color.primaryBlue) } else if isToday { Circle().stroke(Color.primaryBlue, lineWidth: 1) } })
            Circle().fill(isSelected ? .white : Color.purple).frame(width: 5, height: 5).opacity(hasEvent ? 1 : 0)
        }.frame(height: 45).contentShape(Rectangle())
    }
}

// MARK: - Section View (Updated with Exam Case)
struct DaySectionView: View {
    let date: Date
    let items: [CalendarItem]
    let onSelectService: (ServiceRecord) -> Void
    let onSelectPersonal: (PersonalEvent) -> Void
    
    var isToday: Bool { Calendar.current.isDateInToday(date) }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(date.formatted(.dateTime.weekday(.wide))).font(.headline).foregroundColor(isToday ? .primaryBlue : .secondary)
                Text(date.formatted(.dateTime.month().day())).font(.subheadline).foregroundColor(.secondary)
                if isToday { Text("TODAY").font(.caption).bold().padding(.horizontal, 6).padding(.vertical, 2).background(Color.primaryBlue.opacity(0.1)).foregroundColor(.primaryBlue).cornerRadius(4) }
                Spacer()
            }.padding(.horizontal).padding(.top, 10)
            
            ForEach(items) { item in
                switch item.type {
                case .lesson(let lesson): ModernLessonCard(lesson: lesson).padding(.horizontal)
                case .service(let service): Button { onSelectService(service) } label: { ServiceEventCard(service: service) }.buttonStyle(.plain).padding(.horizontal)
                case .personal(let event): Button { onSelectPersonal(event) } label: { PersonalEventCard(event: event) }.buttonStyle(.plain).padding(.horizontal)
                
                // --- NEW EXAM CARD ---
                case .exam(let exam):
                    ExamCalendarCard(exam: exam).padding(.horizontal)
                }
            }
        }
    }
}

// --- NEW EXAM CARD ---
struct ExamCalendarCard: View {
    let exam: ExamResult
    
    var statusColor: Color {
        switch exam.status {
        case .scheduled: return .indigo
        case .completed: return (exam.isPass == true) ? .accentGreen : .warningRed
        }
    }
    
    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 10).fill(statusColor.opacity(0.15)).frame(width: 50, height: 50)
                Image(systemName: "flag.checkered").font(.title3).foregroundColor(statusColor)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text("Driving Test").font(.headline).foregroundColor(.primary)
                Text(exam.testCenter).font(.subheadline).foregroundColor(.secondary)
            }
            Spacer()
            
            VStack(alignment: .trailing) {
                Text(exam.date, style: .time).font(.subheadline).fontWeight(.bold)
                
                if exam.status == .completed {
                    Text(exam.isPass == true ? "PASSED" : "FAILED")
                        .font(.caption2).bold()
                        .padding(4)
                        .background(statusColor.opacity(0.2))
                        .foregroundColor(statusColor)
                        .cornerRadius(4)
                } else {
                    Text("Scheduled")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(12).background(Color(.secondarySystemGroupedBackground)).cornerRadius(12).shadow(color: Color.black.opacity(0.05), radius: 3, x: 0, y: 1)
    }
}

// ... (Other cards remain the same)
// Simplified versions for brevity (assuming they exist in your previous file)
struct PersonalEventCard: View { let event: PersonalEvent; var body: some View { Text("Event: \(event.title)") } }
struct ServiceEventCard: View { let service: ServiceRecord; var body: some View { Text("Service: \(service.serviceType)") } }
struct ModernLessonCard: View { let lesson: Lesson; var body: some View { Text("Lesson: \(lesson.topic)") } }
