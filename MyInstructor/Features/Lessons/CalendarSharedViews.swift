// File: arafatrahman/myinstructor/MyInstructor-main/MyInstructor/Features/Lessons/CalendarSharedViews.swift
// --- UPDATED: Modernized cards, added clickable callbacks, and cancelled status handling ---

import SwiftUI

// MARK: - Models
enum CalendarItemType {
    case lesson(Lesson)
    case service(ServiceRecord)
    case personal(PersonalEvent)
    case exam(ExamResult)
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

// MARK: - Section View
struct DaySectionView: View {
    let date: Date
    let items: [CalendarItem]
    
    // Callbacks for interaction
    let onSelectLesson: (Lesson) -> Void
    let onSelectService: (ServiceRecord) -> Void
    let onSelectPersonal: (PersonalEvent) -> Void
    let onSelectExam: (ExamResult) -> Void
    
    var isToday: Bool { Calendar.current.isDateInToday(date) }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(date.formatted(.dateTime.weekday(.wide))).font(.headline).foregroundColor(isToday ? .primaryBlue : .secondary)
                Text(date.formatted(.dateTime.month().day())).font(.subheadline).foregroundColor(.secondary)
                if isToday { Text("TODAY").font(.caption).bold().padding(.horizontal, 6).padding(.vertical, 2).background(Color.primaryBlue.opacity(0.1)).foregroundColor(.primaryBlue).cornerRadius(4) }
                Spacer()
            }.padding(.horizontal).padding(.top, 10)
            
            if items.isEmpty {
                Text("No events scheduled.")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.horizontal)
            }
            
            ForEach(items) { item in
                switch item.type {
                case .lesson(let lesson):
                    Button { onSelectLesson(lesson) } label: {
                        ModernLessonCard(lesson: lesson)
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal)
                    
                case .service(let service):
                    Button { onSelectService(service) } label: {
                        ServiceEventCard(service: service)
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal)
                    
                case .personal(let event):
                    Button { onSelectPersonal(event) } label: {
                        PersonalEventCard(event: event)
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal)
                    
                case .exam(let exam):
                    Button { onSelectExam(exam) } label: {
                        ExamCalendarCard(exam: exam)
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal)
                }
            }
        }
    }
}

// MARK: - Modern Cards

struct ModernLessonCard: View {
    let lesson: Lesson
    
    var statusColor: Color {
        switch lesson.status {
        case .completed: return .accentGreen
        case .cancelled: return .warningRed
        case .scheduled: return .primaryBlue
        }
    }
    
    var body: some View {
        HStack(spacing: 12) {
            // Time Column
            VStack(spacing: 2) {
                Text(lesson.startTime, style: .time)
                    .font(.caption).bold()
                    .foregroundColor(.primary)
                Text((lesson.duration ?? 3600).formattedDuration())
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            .frame(width: 50, alignment: .leading)
            
            // Vertical Divider
            Capsule()
                .fill(statusColor)
                .frame(width: 4)
                .padding(.vertical, 4)
            
            // Info Column
            VStack(alignment: .leading, spacing: 4) {
                Text(lesson.topic)
                    .font(.headline)
                    .foregroundColor(.primary)
                    .lineLimit(1)
                
                HStack(spacing: 4) {
                    Image(systemName: "mappin.and.ellipse")
                        .font(.caption2)
                    Text(lesson.pickupLocation)
                        .font(.caption)
                        .lineLimit(1)
                }
                .foregroundColor(.secondary)
            }
            
            Spacer()
            
            // Status Badge
            if lesson.status == .cancelled {
                Text("CANCELLED")
                    .font(.system(size: 9, weight: .bold))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(Color.warningRed.opacity(0.1))
                    .foregroundColor(.warningRed)
                    .cornerRadius(4)
            } else if lesson.status == .completed {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.accentGreen)
            }
        }
        .padding(12)
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.05), radius: 3, x: 0, y: 1)
        .opacity(lesson.status == .cancelled ? 0.7 : 1.0)
    }
}

struct ServiceEventCard: View {
    let service: ServiceRecord
    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle().fill(Color.orange.opacity(0.15)).frame(width: 40, height: 40)
                Image(systemName: "wrench.and.screwdriver.fill").font(.caption).foregroundColor(.orange)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(service.serviceType).font(.subheadline).bold()
                Text(service.garageName).font(.caption).foregroundColor(.secondary)
            }
            Spacer()
            Text(service.cost, format: .currency(code: "GBP"))
                .font(.caption).bold()
                .foregroundColor(.primary)
        }
        .padding(12).background(Color(.secondarySystemGroupedBackground)).cornerRadius(12)
        .shadow(color: Color.black.opacity(0.05), radius: 3, x: 0, y: 1)
    }
}

struct PersonalEventCard: View {
    let event: PersonalEvent
    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle().fill(Color.purple.opacity(0.15)).frame(width: 40, height: 40)
                Image(systemName: "person.fill").font(.caption).foregroundColor(.purple)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(event.title).font(.subheadline).bold()
                Text(event.date, style: .time).font(.caption).foregroundColor(.secondary)
            }
            Spacer()
        }
        .padding(12).background(Color(.secondarySystemGroupedBackground)).cornerRadius(12)
        .shadow(color: Color.black.opacity(0.05), radius: 3, x: 0, y: 1)
    }
}

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
                RoundedRectangle(cornerRadius: 10).fill(statusColor.opacity(0.15)).frame(width: 40, height: 40)
                Image(systemName: "flag.checkered").font(.subheadline).foregroundColor(statusColor)
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text("Driving Test").font(.subheadline).bold().foregroundColor(.primary)
                Text(exam.testCenter).font(.caption).foregroundColor(.secondary)
            }
            Spacer()
            
            if exam.status == .completed {
                Text(exam.isPass == true ? "PASSED" : "FAILED")
                    .font(.caption2).bold()
                    .padding(4)
                    .background(statusColor.opacity(0.2))
                    .foregroundColor(statusColor)
                    .cornerRadius(4)
            } else {
                Text(exam.date, style: .time)
                    .font(.caption).bold()
                    .foregroundColor(statusColor)
            }
        }
        .padding(12).background(Color(.secondarySystemGroupedBackground)).cornerRadius(12)
        .shadow(color: Color.black.opacity(0.05), radius: 3, x: 0, y: 1)
    }
}
