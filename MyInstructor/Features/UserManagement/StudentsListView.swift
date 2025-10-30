// File: arafatrahman/myinstructor/MyInstructor-main/MyInstructor/Features/UserManagement/StudentsListView.swift
// --- UPDATED to show Pending Requests and Approved Students ---

import SwiftUI

// Flow Item 11: Students List (Instructor Only)
struct StudentsListView: View {
    @EnvironmentObject var authManager: AuthManager
    @EnvironmentObject var dataService: DataService
    @EnvironmentObject var communityManager: CommunityManager // --- ADDED ---
    
    @State private var approvedStudents: [Student] = [] // --- RENAMED ---
    @State private var pendingRequests: [StudentRequest] = [] // --- ADDED ---
    
    @State private var isLoading = true
    @State private var searchText = ""
    @State private var filterMode: StudentFilter = .active
    
    // Computed property for filtering *approved* students only
    var filteredApprovedStudents: [Student] {
        let list = approvedStudents.filter { student in
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
                } else if pendingRequests.isEmpty && approvedStudents.isEmpty {
                    // Show empty state if both lists are empty
                    EmptyStateView(
                        icon: "person.3.fill",
                        message: "No students or requests yet. Students can find and request you from the Community Directory."
                    )
                } else {
                    List {
                        // --- SECTION 1: PENDING REQUESTS ---
                        if !pendingRequests.isEmpty {
                            Section(header: Text("Pending Requests").font(.headline).foregroundColor(.accentGreen)) {
                                ForEach(pendingRequests) { request in
                                    RequestRow(request: request, onApprove: {
                                        Task { await handleRequest(request, approve: true) }
                                    }, onDeny: {
                                        Task { await handleRequest(request, approve: false) }
                                    })
                                    .listRowInsets(EdgeInsets(top: 8, leading: 0, bottom: 8, trailing: 0))
                                    .listRowSeparator(.hidden)
                                }
                            }
                        }
                        
                        // --- SECTION 2: APPROVED STUDENTS ---
                        // Only show this section if search is not active, or if search results exist
                        if searchText.isEmpty || !filteredApprovedStudents.isEmpty {
                            Section("Approved Students (\(filteredApprovedStudents.count))") {
                                ForEach(filteredApprovedStudents) { student in
                                    NavigationLink {
                                        StudentProfileView(student: student) // Navigate to Flow 12
                                    } label: {
                                        StudentListCard(student: student)
                                    }
                                    // --- ADDED SWIPE ACTION ---
                                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                        Button(role: .destructive) {
                                            Task { await removeStudent(student) }
                                        } label: {
                                            Label("Remove", systemImage: "trash.fill")
                                        }
                                    }
                                }
                                .listRowSeparator(.hidden)
                                .listRowInsets(EdgeInsets(top: 8, leading: 10, bottom: 8, trailing: 10))
                            }
                        }
                    }
                    .listStyle(.insetGrouped) // Changed to grouped for better sectioning
                }
            }
            .navigationTitle("Your Students")
            .toolbar {
                // Toolbar is now clean
            }
            .task {
                await fetchData() // --- RENAMED ---
            }
            .refreshable {
                await fetchData() // --- RENAMED ---
            }
        }
    }
    
    // --- UPDATED FUNCTION ---
    func fetchData() async {
        guard let instructorID = authManager.user?.id else { return }
        isLoading = true
        
        // Fetch both lists in parallel
        async let studentsTask = dataService.fetchStudents(for: instructorID)
        async let requestsTask = communityManager.fetchRequests(for: instructorID)
        
        do {
            self.approvedStudents = try await studentsTask
            self.pendingRequests = try await requestsTask
        } catch {
            print("Failed to fetch data: \(error)")
        }
        isLoading = false
    }
    
    // --- NEW FUNCTION ---
    func handleRequest(_ request: StudentRequest, approve: Bool) async {
        do {
            if approve {
                try await communityManager.approveRequest(request)
            } else {
                try await communityManager.denyRequest(request)
            }
            await fetchData() // Refresh both lists
        } catch {
            print("Failed to handle request: \(error)")
        }
    }
    
    // --- NEW FUNCTION ---
    func removeStudent(_ student: Student) async {
        guard let instructorID = authManager.user?.id, let studentID = student.id else { return }
        
        do {
            try await communityManager.removeStudent(studentID: studentID, instructorID: instructorID)
            await fetchData() // Refresh both lists
        } catch {
            print("Failed to remove student: \(error)")
        }
    }
}

enum StudentFilter: String {
    case all, active, completed
}

// (StudentListCard is unchanged, but we must add RequestRow)

// --- COPIED FROM NOTIFICATIONSVIEW.SWIFT ---
// This is the card for pending requests
struct RequestRow: View {
    let request: StudentRequest
    let onApprove: () -> Void
    let onDeny: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                AsyncImage(url: URL(string: request.studentPhotoURL ?? "")) { phase in
                    if let image = phase.image {
                        image.resizable().scaledToFill()
                    } else {
                        Image(systemName: "person.circle.fill")
                            .resizable()
                            .foregroundColor(.primaryBlue)
                    }
                }
                .frame(width: 50, height: 50)
                .clipShape(Circle())
                
                VStack(alignment: .leading) {
                    Text(request.studentName)
                        .font(.headline)
                    Text("Sent \(request.timestamp.formatted(.relative(presentation: .named)))")
                        .font(.caption)
                        .foregroundColor(.textLight)
                }
                Spacer()
            }
            
            Text("\"I would like to request you as my instructor.\"")
                .font(.subheadline)
                .italic()
                .padding(.leading, 62)
                
            HStack(spacing: 10) {
                Button("Deny", role: .destructive, action: onDeny)
                    .buttonStyle(.secondaryDrivingApp)
                    .frame(maxWidth: .infinity)
                    
                Button("Approve", action: onApprove)
                    .buttonStyle(.primaryDrivingApp)
                    .frame(maxWidth: .infinity)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
    }
}


// (StudentListCard is unchanged)
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
            CircularProgressView(progress: student.averageProgress, color: progressColor, size: 50)
                .overlay(
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
                )
                .frame(width: 50, height: 50)
            
            VStack(alignment: .leading) {
                Text(student.name)
                    .font(.headline)
                
                HStack {
                    Image(systemName: student.nextLessonTime != nil ? "clock.fill" : "calendar.badge.exclamationmark")
                        .font(.caption)
                    Text(nextLessonTimeString)
                        .font(.caption)
                }
                .foregroundColor(.textLight)
            }
            
            Spacer()
            
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
