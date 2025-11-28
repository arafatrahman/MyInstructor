// File: arafatrahman/myinstructor/MyInstructor-main/MyInstructor/Features/Student/StudentCalendarView.swift
// --- NEW FILE: Calendar View specifically for Students ---

import SwiftUI

struct StudentCalendarView: View {
    @EnvironmentObject var lessonManager: LessonManager
    @EnvironmentObject var authManager: AuthManager
    
    @State private var selectedDate: Date = Date()
    @State private var calendarItems: [CalendarItem] = []
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
                    // Reuse Modern Week Picker from Instructor View
                    ModernWeekHeader(selectedDate: $selectedDate)
                        .background(Color(.systemBackground))
                        .shadow(color: Color.black.opacity(0.05), radius: 5, y: 5)
                        .zIndex(1)
                    
                    if isLoading {
                        Spacer()
                        ProgressView("Loading Your Schedule...")
                        Spacer()
                    } else if calendarItems.isEmpty {
                        EmptyStateView(
                            icon: "calendar",
                            message: "No lessons scheduled for this week.",
                            actionTitle: "Refresh",
                            action: { Task { await fetchStudentCalendarData() } }
                        )
                    } else {
                        // Timeline Scroll View
                        ScrollView {
                            LazyVStack(spacing: 20) {
                                ForEach(itemsByDay, id: \.0) { (date, dailyItems) in
                                    // Reuse DaySectionView
                                    DaySectionView(
                                        date: date,
                                        items: dailyItems,
                                        onSelectService: { _ in } // Students don't edit services
                                    )
                                }
                            }
                            .padding(.vertical, 20)
                        }
                    }
                }
            }
            .navigationTitle("My Schedule")
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
            }
            .onAppear {
                Task { await fetchStudentCalendarData() }
            }
            .onChange(of: selectedDate) { _, _ in
                Task { await fetchStudentCalendarData() }
            }
        }
    }
    
    private func fetchStudentCalendarData() async {
        guard let studentID = authManager.user?.id else { return }
        
        isLoading = true
        let start = startOfWeek
        let end = Calendar.current.date(byAdding: .day, value: 7, to: start) ?? Date()
        
        do {
            // Fetch Lessons specifically for this student
            let fetchedLessons = try await lessonManager.fetchLessonsForStudent(studentID: studentID, start: start, end: end)
            
            // Map to CalendarItems
            self.calendarItems = fetchedLessons.map { CalendarItem(id: $0.id ?? UUID().uuidString, date: $0.startTime, type: .lesson($0)) }
            
            // Sort
            self.calendarItems.sort(by: { $0.date < $1.date })
            
        } catch {
            print("Error fetching student calendar: \(error)")
        }
        isLoading = false
    }
}
