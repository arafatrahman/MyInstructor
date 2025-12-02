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

// MARK: - Header
struct ModernWeekHeader: View {
    @Binding var selectedDate: Date
    private let calendar = Calendar.current
    
    var weekRangeString: String {
        let start = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: selectedDate)) ?? selectedDate
        let end = calendar.date(byAdding: .day, value: 6, to: start) ?? start
        let formatter = DateFormatter(); formatter.dateFormat = "MMM d"
        return "\(formatter.string(from: start)) – \(formatter.string(from: end))"
    }
    
    var body: some View {
        HStack {
            Button { withAnimation { selectedDate = calendar.date(byAdding: .weekOfYear, value: -1, to: selectedDate) ?? selectedDate } } label: {
                Image(systemName: "chevron.left.circle.fill").font(.title3).foregroundColor(.secondary)
            }
            Spacer()
            VStack(spacing: 2) {
                Text(weekRangeString).font(.headline).foregroundColor(.primary)
                Text(calendar.component(.year, from: selectedDate).description.replacingOccurrences(of: ",", with: "")).font(.caption).foregroundColor(.secondary)
            }
            Spacer()
            Button { withAnimation { selectedDate = calendar.date(byAdding: .weekOfYear, value: 1, to: selectedDate) ?? selectedDate } } label: {
                Image(systemName: "chevron.right.circle.fill").font(.title3).foregroundColor(.secondary)
            }
        }.padding()
    }
}

// MARK: - Section View
struct DaySectionView: View {
    let date: Date
    let items: [CalendarItem]
    let onSelectService: (ServiceRecord) -> Void
    let onSelectPersonal: (PersonalEvent) -> Void
    
    var isToday: Bool { Calendar.current.isDateInToday(date) }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(date.formatted(.dateTime.weekday(.wide))).font(.title3).bold().foregroundColor(isToday ? .primaryBlue : .primary)
                Text(date.formatted(.dateTime.month().day())).font(.subheadline).foregroundColor(.secondary)
                if isToday { Text("TODAY").font(.caption).bold().padding(.horizontal, 6).padding(.vertical, 2).background(Color.primaryBlue.opacity(0.1)).foregroundColor(.primaryBlue).cornerRadius(4) }
                Spacer()
            }.padding(.horizontal)
            
            ForEach(items) { item in
                switch item.type {
                case .lesson(let lesson):
                    ModernLessonCard(lesson: lesson).padding(.horizontal)
                case .service(let service):
                    Button { onSelectService(service) } label: { ServiceEventCard(service: service) }.buttonStyle(.plain).padding(.horizontal)
                case .personal(let event):
                    Button { onSelectPersonal(event) } label: { PersonalEventCard(event: event) }.buttonStyle(.plain).padding(.horizontal)
                }
            }
        }
    }
}

// MARK: - Cards

// 1. Personal Event Card (Redesigned with Swipe Delete)
struct PersonalEventCard: View {
    let event: PersonalEvent
    @EnvironmentObject var personalEventManager: PersonalEventManager
    
    var body: some View {
        HStack(spacing: 15) {
            VStack(alignment: .center, spacing: 2) {
                Text(event.date, style: .time).font(.headline).bold().foregroundColor(.primary)
            }.frame(width: 60)
            
            Capsule().fill(Color.purple).frame(width: 4).padding(.vertical, 4)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(event.title).font(.headline).foregroundColor(.primary)
                Text(event.notes?.isEmpty == false ? event.notes! : "Personal").font(.caption).foregroundColor(.secondary.opacity(0.7)).lineLimit(1)
            }
            Spacer()
            Image(systemName: "person.circle").font(.title2).foregroundColor(.purple.opacity(0.6))
        }
        .padding(12)
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.05), radius: 3, x: 0, y: 1)
        .swipeActions(edge: .trailing) {
            Button(role: .destructive) {
                Task { try? await personalEventManager.deleteEvent(id: event.id ?? "") }
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
    }
}

// 2. Service Card
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
                    HStack(spacing: 4) { Image(systemName: "calendar.badge.clock"); Text("Due: \(nextDate.formatted(date: .abbreviated, time: .omitted))") }.font(.caption).foregroundColor(.orange)
                }
            }.padding(16)
            Spacer()
            Image(systemName: "chevron.right").foregroundColor(.secondary.opacity(0.3)).padding(.trailing, 16).padding(.top, 40)
        }.background(Color(.secondarySystemGroupedBackground)).cornerRadius(12).shadow(color: Color.black.opacity(0.05), radius: 4, x: 0, y: 2)
    }
}

// 3. Lesson Card
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
