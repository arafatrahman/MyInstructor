// File: arafatrahman/myinstructor/MyInstructor-main/MyInstructor/Features/UserManagement/StudentsListView.swift
import SwiftUI

// Flow Item 11: Students List (Instructor Only)
struct StudentsListView: View {
    @EnvironmentObject var authManager: AuthManager
    @EnvironmentObject var dataService: DataService
    
    @State private var students: [Student] = []
    @State private var isLoading = true
    @State private var searchText = ""
    @State private var filterMode: StudentFilter = .active // Filter (Active/Completed)
    
    // --- REMOVED: isAddStudentModalPresented ---
    
    // Computed property for filtering and searching
    var filteredStudents: [Student] {
        let list = students.filter { student in
            switch filterMode {
            case .all: return true
            case .active: return student.averageProgress < 1.0 // Active if not 100%
            case .completed: return student.averageProgress >= 1.0
            }
        }
        
        if searchText.isEmpty {
            return list
        } else {
            return list.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
        }
    }
    
    var body: some View {
        NavigationView {
            VStack {
                // Top: Search bar + Filter
                HStack {
                    SearchBar(text: $searchText, placeholder: "Search students by name")
                    
                    Picker("Filter", selection: $filterMode) {
                        Text("All").tag(StudentFilter.all)
                        Text("Active").tag(StudentFilter.active)
                        Text("Completed").tag(StudentFilter.completed)
                    }
                    .pickerStyle(.menu)
                    .frame(width: 110)
                    .foregroundColor(.primaryBlue)
                }
                .padding(.horizontal)
                
                if isLoading {
                    ProgressView("Loading Students...")
                        .padding(.top, 50)
                } else if filteredStudents.isEmpty && students.isEmpty {
                    // --- UPDATED EMPTY STATE ---
                    EmptyStateView(
                        icon: "person.3.fill",
                        message: "No students have been approved yet. Students can find and request you from the Community Directory."
                    )
                } else if filteredStudents.isEmpty {
                    Text("No students found matching the criteria.")
                        .foregroundColor(.textLight)
                        .padding()
                } else {
                    List {
                        ForEach(filteredStudents) { student in
                            NavigationLink {
                                StudentProfileView(student: student) // Navigate to Flow 12
                            } label: {
                                StudentListCard(student: student)
                            }
                            .listRowSeparator(.hidden)
                            .listRowInsets(EdgeInsets(top: 8, leading: 10, bottom: 8, trailing: 10))
                        }
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("Your Students")
            .toolbar {
                // --- REMOVED ToolbarItem ---
            }
            .task {
                await fetchStudents()
            }
            .refreshable {
                await fetchStudents()
            }
            // --- REMOVED .sheet ---
        }
    }
    
    func fetchStudents() async {
        guard let instructorID = authManager.user?.id else { return }
        isLoading = true
        do {
            // This function is now fixed in DataService.swift
            self.students = try await dataService.fetchStudents(for: instructorID)
        } catch {
            print("Failed to fetch students: \(error)")
        }
        isLoading = false
    }
}

enum StudentFilter: String {
    case all, active, completed
}

// Student List Card (Flow Item 11 detail)
struct StudentListCard: View {
    let student: Student
    
    var progressColor: Color {
        if student.averageProgress > 0.8 { return .accentGreen }
        if student.averageProgress > 0.5 { return .orange }
        return .warningRed
    }
    
    var nextLessonTimeString: String {
        if let nextLesson = student.nextLessonTime {
            let formatter = DateFormatter()
            formatter.dateFormat = "EEE, h:mm a"
            return formatter.string(from: nextLesson)
        }
        return "Not Scheduled"
    }

    var body: some View {
        HStack {
            // Photo & Progress Circle
            CircularProgressView(progress: student.averageProgress, color: progressColor, size: 50)
                .overlay(
                    // --- Use AsyncImage for student photo ---
                    AsyncImage(url: URL(string: student.photoURL ?? "")) { phase in
                        if let image = phase.image {
                            image.resizable().scaledToFill()
                        } else {
                            Image(systemName: "person.crop.circle.fill")
                                .font(.title2)
                                .foregroundColor(progressColor)
                        }
                    }
                    .frame(width: 45, height: 45)
                    .clipShape(Circle())
                    // --- End AsyncImage ---
                )
                .frame(width: 50, height: 50)
            
            VStack(alignment: .leading) {
                // Name
                Text(student.name)
                    .font(.headline)
                
                // Next Lesson
                HStack {
                    Image(systemName: student.nextLessonTime != nil ? "clock.fill" : "calendar.badge.exclamationmark")
                        .font(.caption)
                    Text(nextLessonTimeString)
                        .font(.caption)
                }
                .foregroundColor(.textLight)
            }
            
            Spacer()
            
            // Progress Indicator (Text)
            VStack(alignment: .trailing) {
                Text("\(Int(student.averageProgress * 100))%")
                    .font(.title3).bold()
                    .foregroundColor(progressColor)
                
                Text("Mastery")
                    .font(.caption)
                    .foregroundColor(.textLight)
            }
        }
        .padding(10)
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: Color.textDark.opacity(0.05), radius: 5, x: 0, y: 2)
    }
}
