// File: MyInstructor/Features/Lessons/CalendarSharedViews.swift
import SwiftUI

// MARK: - Models
enum CalendarItemType {
    case lesson(Lesson)
    case service(ServiceRecord)
    case personal(PersonalEvent)
}

struct CalendarItem: Identifiable {
    let id: String
    let date: Date
    let type: CalendarItemType
}

// MARK: - Custom Monthly Calendar
struct CustomMonthlyCalendar: View {
    @Binding var selectedDate: Date
    let eventDates: Set<DateComponents> // Dates that should have a dot
    
    @State private var currentMonth: Date = Date()
    private let calendar = Calendar.current
    private let daysOfWeek = ["M", "T", "W", "T", "F", "S", "S"]
    
    // Grid Setup
    private let columns = Array(repeating: GridItem(.flexible()), count: 7)
    
    var body: some View {
        VStack(spacing: 15) {
            
            // 1. Month Header & Navigation
            HStack {
                Button { changeMonth(by: -1) } label: {
                    Image(systemName: "chevron.left")
                        .font(.headline)
                        .foregroundColor(.primary)
                }
                
                Spacer()
                
                Text(monthYearString(for: currentMonth))
                    .font(.title3).bold()
                    .foregroundColor(.primary)
                
                Spacer()
                
                Button { changeMonth(by: 1) } label: {
                    Image(systemName: "chevron.right")
                        .font(.headline)
                        .foregroundColor(.primary)
                }
            }
            .padding(.horizontal)
            
            // 2. Weekday Headers
            HStack {
                ForEach(daysOfWeek, id: \.self) { day in
                    Text(day)
                        .font(.caption2).bold()
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity)
                }
            }
            
            // 3. Days Grid
            LazyVGrid(columns: columns, spacing: 10) {
                ForEach(daysInMonth(), id: \.self) { date in
                    if let date = date {
                        DayCell(
                            date: date,
                            isSelected: calendar.isDate(date, inSameDayAs: selectedDate),
                            isToday: calendar.isDateInToday(date),
                            hasEvent: hasEvent(on: date)
                        )
                        .onTapGesture {
                            withAnimation {
                                selectedDate = date
                            }
                        }
                    } else {
                        // Empty spacer for offset days
                        Text("")
                            .frame(maxWidth: .infinity, minHeight: 40)
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.05), radius: 5, y: 5)
        .onAppear {
            currentMonth = selectedDate
        }
    }
    
    // MARK: - Logic
    
    private func changeMonth(by value: Int) {
        if let newMonth = calendar.date(byAdding: .month, value: value, to: currentMonth) {
            withAnimation {
                currentMonth = newMonth
            }
        }
    }
    
    private func monthYearString(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        return formatter.string(from: date)
    }
    
    private func daysInMonth() -> [Date?] {
        guard let monthInterval = calendar.dateInterval(of: .month, for: currentMonth),
              let firstDayOfMonth = monthInterval.start as Date? else { return [] }
        
        let daysInMonth = calendar.range(of: .day, in: .month, for: currentMonth)?.count ?? 0
        
        // Calculate offset (e.g., if month starts on Tuesday)
        // Note: weekday returns 1 for Sunday, 2 for Monday. We want Mon=0, Sun=6
        let firstWeekday = calendar.component(.weekday, from: firstDayOfMonth)
        // Convert 1(Sun)..7(Sat) to 0(Mon)..6(Sun) for standard ISO week
        // or just use default. Let's assume standard US/UK where 1=Sun.
        // If your calendar prefers Monday start, adjust logic.
        // Here assuming Monday start:
        // Sun=1 -> 6, Mon=2 -> 0, Tue=3 -> 1...
        let offset = (firstWeekday + 5) % 7
        
        var days: [Date?] = Array(repeating: nil, count: offset)
        
        for i in 0..<daysInMonth {
            if let date = calendar.date(byAdding: .day, value: i, to: firstDayOfMonth) {
                days.append(date)
            }
        }
        return days
    }
    
    private func hasEvent(on date: Date) -> Bool {
        let components = calendar.dateComponents([.year, .month, .day], from: date)
        return eventDates.contains(components)
    }
}

struct DayCell: View {
    let date: Date
    let isSelected: Bool
    let isToday: Bool
    let hasEvent: Bool
    
    var body: some View {
        VStack(spacing: 4) {
            Text(date.formatted(.dateTime.day()))
                .font(.subheadline)
                .fontWeight(isSelected || isToday ? .bold : .regular)
                .foregroundColor(isSelected ? .white : (isToday ? .primaryBlue : .primary))
                .frame(width: 32, height: 32)
                .background(
                    ZStack {
                        if isSelected {
                            Circle().fill(Color.primaryBlue)
                        } else if isToday {
                            Circle().stroke(Color.primaryBlue, lineWidth: 1)
                        }
                    }
                )
            
            // Event Dot
            Circle()
                .fill(isSelected ? .white : Color.purple)
                .frame(width: 5, height: 5)
                .opacity(hasEvent ? 1 : 0)
        }
        .frame(height: 45)
        .contentShape(Rectangle())
    }
}

// MARK: - Section View (Unchanged)
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
                }
            }
        }
    }
}

// MARK: - Cards (Unchanged from previous correct version)
struct PersonalEventCard: View {
    let event: PersonalEvent
    @EnvironmentObject var personalEventManager: PersonalEventManager
    var body: some View {
        HStack(spacing: 12) {
            ZStack { RoundedRectangle(cornerRadius: 10).fill(Color.purple.opacity(0.15)).frame(width: 50, height: 50); Image(systemName: "person.fill").font(.title3).foregroundColor(.purple) }
            VStack(alignment: .leading, spacing: 4) {
                Text(event.title).font(.headline).foregroundColor(.primary)
                if let notes = event.notes, !notes.isEmpty { Text(notes).font(.caption).foregroundColor(.secondary).lineLimit(1) }
                else { Text("Personal Event").font(.caption).foregroundColor(.secondary.opacity(0.7)) }
            }
            Spacer()
            Text(event.date, style: .time).font(.subheadline).fontWeight(.bold).foregroundColor(.primary).padding(.horizontal, 8).padding(.vertical, 4).background(Color(.systemGray6)).cornerRadius(6)
        }
        .padding(12).background(Color(.secondarySystemGroupedBackground)).cornerRadius(12).shadow(color: Color.black.opacity(0.05), radius: 3, x: 0, y: 1)
        .swipeActions(edge: .trailing) { Button(role: .destructive) { Task { try? await personalEventManager.deleteEvent(id: event.id ?? "") } } label: { Label("Delete", systemImage: "trash") } }
    }
}

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
                if let nextDate = service.nextServiceDate { HStack(spacing: 4) { Image(systemName: "calendar.badge.clock"); Text("Due: \(nextDate.formatted(date: .abbreviated, time: .omitted))") }.font(.caption).foregroundColor(.orange) }
            }.padding(16)
            Spacer()
            Image(systemName: "chevron.right").foregroundColor(.secondary.opacity(0.3)).padding(.trailing, 16).padding(.top, 40)
        }.background(Color(.secondarySystemGroupedBackground)).cornerRadius(12).shadow(color: Color.black.opacity(0.05), radius: 4, x: 0, y: 2)
    }
}

struct ModernLessonCard: View {
    @EnvironmentObject var dataService: DataService; let lesson: Lesson; @State private var studentName: String = "Loading..."
    private var statusConfig: (text: String, color: Color) {
        switch lesson.status {
        case .completed: return ("Finished", .accentGreen)
        case .cancelled: return ("Cancelled", .warningRed)
        case .scheduled:
            let now = Date(); let endTime = lesson.startTime.addingTimeInterval(lesson.duration ?? 3600)
            if endTime < now { return ("Pending", .orange) } else if lesson.startTime <= now && endTime >= now { return ("Active", .primaryBlue) } else if lesson.startTime > now && lesson.startTime.timeIntervalSince(now) < 3600 { return ("Up Next", .primaryBlue) } else { return ("Booked", .secondary) }
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
            }.background(Color(.secondarySystemGroupedBackground)).cornerRadius(12).shadow(color: Color.black.opacity(0.05), radius: 4, x: 0, y: 2)
        }.buttonStyle(.plain).task { if let user = try? await dataService.fetchUser(withId: lesson.studentID) { self.studentName = user.name ?? "Unknown Student" } else { self.studentName = "Student" } }
    }
}
