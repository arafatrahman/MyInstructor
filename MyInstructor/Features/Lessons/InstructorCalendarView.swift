// File: arafatrahman/myinstructor/MyInstructor-main/MyInstructor/Features/Lessons/InstructorCalendarView.swift
// --- UPDATED: Added Status Badge (Finish, Pending, Up Next) below duration ---

import SwiftUI

// Flow Item 7: Instructor Calendar View
struct InstructorCalendarView: View {
    @EnvironmentObject var lessonManager: LessonManager
    @EnvironmentObject var dataService: DataService
    @EnvironmentObject var authManager: AuthManager
    
    @State private var selectedDate: Date = Date()
    @State private var lessons: [Lesson] = []
    @State private var isAddLessonSheetPresented = false
    @State private var isLoading = false
    
    // Computed property: Group lessons by the start of the day
    private var lessonsByDay: [(Date, [Lesson])] {
        let grouped = Dictionary(grouping: lessons) { lesson in
            Calendar.current.startOfDay(for: lesson.startTime)
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
                Color(.systemGroupedBackground) // Modern background color
                    .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // MARK: - Modern Week Picker
                    ModernWeekHeader(selectedDate: $selectedDate)
                        .background(Color(.systemBackground))
                        .shadow(color: Color.black.opacity(0.05), radius: 5, y: 5)
                        .zIndex(1) // Keep header on top
                    
                    if isLoading {
                        Spacer()
                        ProgressView("Loading Schedule...")
                        Spacer()
                    } else if lessons.isEmpty {
                        EmptyStateView(
                            icon: "calendar.badge.plus",
                            message: "No lessons scheduled for this week.",
                            actionTitle: "Add Lesson",
                            action: { isAddLessonSheetPresented = true }
                        )
                    } else {
                        // MARK: - Timeline Scroll View
                        ScrollView {
                            LazyVStack(spacing: 20) {
                                ForEach(lessonsByDay, id: \.0) { (date, dailyLessons) in
                                    DaySectionView(date: date, lessons: dailyLessons)
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
                    // "Today" Button to jump back
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
                Task { await fetchLessons() }
            }
            .onChange(of: selectedDate) { _, _ in
                Task { await fetchLessons() }
            }
            .sheet(isPresented: $isAddLessonSheetPresented) {
                AddLessonFormView(onLessonAdded: { _ in
                    Task { await fetchLessons() }
                })
            }
        }
    }
    
    private func fetchLessons() async {
        guard let instructorID = authManager.user?.id else { return }
        
        isLoading = true
        let start = startOfWeek
        let end = Calendar.current.date(byAdding: .day, value: 7, to: start) ?? Date()
        
        do {
            let fetchedLessons = try await lessonManager.fetchLessons(for: instructorID, start: start, end: end)
            // We show all lessons (including completed/cancelled) so history is visible
            self.lessons = fetchedLessons
        } catch {
            print("Error fetching lessons: \(error)")
        }
        isLoading = false
    }
}

// MARK: - Subviews

// 1. Header Component
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

// 2. Day Section (Groups lessons by date)
struct DaySectionView: View {
    let date: Date
    let lessons: [Lesson]
    
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
            
            // Lessons
            ForEach(lessons.sorted(by: { $0.startTime < $1.startTime })) { lesson in
                ModernLessonCard(lesson: lesson)
                    .padding(.horizontal)
            }
        }
    }
}

// 3. The Modern Card
struct ModernLessonCard: View {
    @EnvironmentObject var dataService: DataService
    let lesson: Lesson
    
    // Helper to get student name
    @State private var studentName: String = "Loading..."
    
    // --- Logic for Status Display ---
    private var statusConfig: (text: String, color: Color) {
        switch lesson.status {
        case .completed:
            return ("Finished", .accentGreen)
        case .cancelled:
            return ("Cancelled", .warningRed)
        case .scheduled:
            let now = Date()
            // End time = Start + Duration (default 1h if nil)
            let endTime = lesson.startTime.addingTimeInterval(lesson.duration ?? 3600)
            
            if endTime < now {
                // Scheduled time has passed but not marked completed
                return ("Pending", .orange)
            } else if lesson.startTime <= now && endTime >= now {
                // Currently within the lesson time
                return ("Active", .primaryBlue)
            } else if lesson.startTime > now && lesson.startTime.timeIntervalSince(now) < 3600 {
                // Starts within the next hour
                return ("Up Next", .primaryBlue)
            } else {
                // Future
                return ("Booked", .secondary)
            }
        }
    }
    
    var body: some View {
        NavigationLink(destination: LessonDetailsView(lesson: lesson)) {
            HStack(alignment: .top, spacing: 0) {
                // Left: Time Strip
                VStack(alignment: .center, spacing: 6) {
                    Text(lesson.startTime, style: .time)
                        .font(.subheadline).bold()
                        .foregroundColor(.primary)
                        .multilineTextAlignment(.center)
                    
                    // Duration pill
                    Text(lesson.duration?.formattedDuration() ?? "1h")
                        .font(.caption2).bold()
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.secondaryGray)
                        .foregroundColor(.secondary)
                        .cornerRadius(4)
                    
                    // --- STATUS BADGE ---
                    Text(statusConfig.text)
                        .font(.system(size: 9, weight: .bold))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(statusConfig.color.opacity(0.15))
                        .foregroundColor(statusConfig.color)
                        .cornerRadius(4)
                        .lineLimit(1)
                        .fixedSize(horizontal: true, vertical: false) // Prevent truncation if possible
                }
                .frame(width: 75) // Slightly wider to fit status
                .padding(.vertical, 16)
                
                // Vertical Divider
                Rectangle()
                    .fill(Color.secondaryGray)
                    .frame(width: 1)
                    .padding(.vertical, 10)
                
                // Right: Content
                VStack(alignment: .leading, spacing: 6) {
                    // Topic
                    Text(lesson.topic)
                        .font(.headline)
                        .foregroundColor(.primary)
                        .lineLimit(1)
                    
                    // Student Name
                    HStack(spacing: 6) {
                        Image(systemName: "person.fill")
                            .font(.caption)
                            .foregroundColor(.primaryBlue)
                        Text(studentName)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                    
                    // Location
                    HStack(spacing: 6) {
                        Image(systemName: "mappin.and.ellipse")
                            .font(.caption)
                            .foregroundColor(.orange)
                        Text(lesson.pickupLocation)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                }
                .padding(16)
                
                Spacer()
                
                // Chevron
                Image(systemName: "chevron.right")
                    .foregroundColor(.secondary.opacity(0.3))
                    .padding(.trailing, 16)
                    .padding(.top, 40)
            }
            .background(Color(.secondarySystemGroupedBackground)) // Card background
            .cornerRadius(12)
            .shadow(color: Color.black.opacity(0.05), radius: 4, x: 0, y: 2)
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
