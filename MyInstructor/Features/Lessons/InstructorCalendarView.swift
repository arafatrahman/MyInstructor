import SwiftUI

// Flow Item 7: Instructor Calendar View
struct InstructorCalendarView: View {
    @EnvironmentObject var lessonManager: LessonManager
    @EnvironmentObject var dataService: DataService
    
    @State private var selectedDate: Date = Date()
    @State private var lessons: [Lesson] = []
    @State private var isAddLessonSheetPresented = false
    @State private var isLoading = false
    
    // Calculate the start of the week (Sunday for simplicity in this mock)
    private var startOfWeek: Date {
        Calendar.current.date(from: Calendar.current.dateComponents([.yearForWeekOfYear, .weekOfYear], from: selectedDate)) ?? selectedDate
    }

    var body: some View {
        NavigationView {
            VStack {
                // MARK: - Week Picker
                WeekHeader(selectedDate: $selectedDate)
                
                if isLoading {
                    ProgressView("Loading lessons...")
                        .padding(.top, 50)
                } else if lessons.isEmpty {
                    EmptyStateView(
                        icon: "calendar.badge.plus",
                        message: "You have no lessons scheduled this week.",
                        actionTitle: "Schedule First Lesson",
                        action: { isAddLessonSheetPresented = true }
                    )
                } else {
                    // MARK: - Lesson List
                    List {
                        ForEach(lessons.sorted(by: { $0.startTime < $1.startTime })) { lesson in
                            LessonRow(lesson: lesson, studentName: dataService.getStudentName(for: lesson.studentID))
                                .listRowSeparator(.hidden)
                                .listRowInsets(EdgeInsets(top: 8, leading: 10, bottom: 8, trailing: 10))
                        }
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("Calendar")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        isAddLessonSheetPresented = true
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.title2)
                            .foregroundColor(.primaryBlue)
                    }
                }
            }
            .onAppear {
                // Set initial date range to load lessons
                Task { await fetchLessons() }
            }
            .onChange(of: selectedDate) { _ in
                // Reload lessons when week changes
                Task { await fetchLessons() }
            }
            .sheet(isPresented: $isAddLessonSheetPresented) {
                AddLessonFormView(onLessonAdded: { 
                    Task { await fetchLessons() }
                })
            }
        }
    }
    
    private func fetchLessons() async {
        isLoading = true
        let start = startOfWeek
        let end = Calendar.current.date(byAdding: .day, value: 7, to: start) ?? Date()
        
        do {
            // NOTE: Using a mock instructor ID for this implementation
            let fetchedLessons = try await lessonManager.fetchLessons(for: "i_auth_id", start: start, end: end)
            self.lessons = fetchedLessons.filter { $0.status == .scheduled }
        } catch {
            print("Error fetching lessons: \(error)")
        }
        isLoading = false
    }
}

// MARK: - Week Navigation Component
struct WeekHeader: View {
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
                selectedDate = calendar.date(byAdding: .weekOfYear, value: -1, to: selectedDate) ?? selectedDate
            } label: {
                Image(systemName: "chevron.left")
            }
            
            Spacer()
            
            Text(weekRangeString)
                .font(.headline)
            
            Spacer()
            
            Button {
                selectedDate = calendar.date(byAdding: .weekOfYear, value: 1, to: selectedDate) ?? selectedDate
            } label: {
                Image(systemName: "chevron.right")
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .foregroundColor(.primaryBlue)
    }
}


// MARK: - Lesson Row Component
struct LessonRow: View {
    let lesson: Lesson
    let studentName: String
    
    var body: some View {
        // NavigationLink leads to Flow 8 (Lesson Details)
        NavigationLink(destination: LessonDetailsView(lesson: lesson)) { 
            HStack(alignment: .top, spacing: 15) {
                // Time Indicator (Colorful)
                VStack(alignment: .trailing) {
                    Text("\(lesson.startTime, style: .time)")
                        .font(.headline)
                    Text("\(lesson.duration?.formattedDuration() ?? "1h")")
                        .font(.caption)
                        .foregroundColor(.textLight)
                }
                .frame(width: 60, alignment: .trailing)
                
                // Content Card
                VStack(alignment: .leading, spacing: 5) {
                    Text(lesson.topic)
                        .font(.body).bold()
                        .foregroundColor(.textDark)
                    
                    Text("Student: \(studentName)")
                        .font(.subheadline)
                        .foregroundColor(.primaryBlue)
                    
                    HStack {
                        Image(systemName: "mappin.and.ellipse")
                        Text(lesson.pickupLocation)
                    }
                    .font(.caption)
                    .foregroundColor(.textLight)
                }
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.secondaryGray)
                .cornerRadius(12)
            }
        }
    }
}
