// File: arafatrahman/myinstructor/MyInstructor-main/MyInstructor/Features/UserManagement/StudentsListView.swift
// --- UPDATED: No code changes needed, this file is correct and will no longer be ambiguous ---

import SwiftUI

struct StudentsListView: View {
    @EnvironmentObject var authManager: AuthManager
    @EnvironmentObject var dataService: DataService
    @EnvironmentObject var communityManager: CommunityManager
    @EnvironmentObject var chatManager: ChatManager
    
    @State private var approvedStudents: [Student] = []
    @State private var pendingRequests: [StudentRequest] = []
    @State private var deniedRequests: [StudentRequest] = []
    @State private var blockedRequests: [StudentRequest] = []
    
    @State private var isLoading = true
    @State private var searchText = ""
    @State private var filterMode: StudentFilter = .pending
    
    @State private var conversationToPush: Conversation? = nil
    
    var filteredApprovedStudents: [Student] {
        // This filter logic is now separate from the main filter
        let list: [Student]
        if filterMode == .active {
            list = approvedStudents.filter { $0.averageProgress < 1.0 }
        } else if filterMode == .completed {
            list = approvedStudents.filter { $0.averageProgress >= 1.0 }
        } else {
            list = approvedStudents // for .all
        }
        
        if searchText.isEmpty {
            return list
        } else {
            return list.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
        }
    }
    
    var filteredPendingRequests: [StudentRequest] {
        if searchText.isEmpty {
            return pendingRequests
        }
        return pendingRequests.filter { $0.studentName.localizedCaseInsensitiveContains(searchText) }
    }
    
    var filteredDeniedRequests: [StudentRequest] {
        if searchText.isEmpty {
            return deniedRequests
        }
        return deniedRequests.filter { $0.studentName.localizedCaseInsensitiveContains(searchText) }
    }
    
    var filteredBlockedRequests: [StudentRequest] {
        if searchText.isEmpty {
            return blockedRequests
        }
        return blockedRequests.filter { $0.studentName.localizedCaseInsensitiveContains(searchText) }
    }

    var body: some View {
        NavigationView {
            VStack {
                if let conversation = conversationToPush {
                    NavigationLink(
                        destination: ChatView(conversation: conversation),
                        isActive: .constant(true),
                        label: { EmptyView() }
                    )
                }
                
                HStack {
                    SearchBar(text: $searchText, placeholder: "Search students by name")
                    
                    Picker("Filter", selection: $filterMode) {
                        Text("Pending").tag(StudentFilter.pending)
                        Text("Active").tag(StudentFilter.active)
                        Text("Completed").tag(StudentFilter.completed)
                        Text("Denied").tag(StudentFilter.denied)
                        Text("Blocked").tag(StudentFilter.blocked)
                        Text("All Students").tag(StudentFilter.all)
                    }
                    .pickerStyle(.menu)
                    .frame(width: 110)
                    .foregroundColor(.primaryBlue)
                }
                .padding(.horizontal)
                
                if isLoading {
                    ProgressView("Loading Students...")
                        .padding(.top, 50)
                } else if pendingRequests.isEmpty && approvedStudents.isEmpty && deniedRequests.isEmpty && blockedRequests.isEmpty {
                    EmptyStateView(
                        icon: "person.3.fill",
                        message: "No students or requests yet. Students can find and request you from the Community Directory."
                    )
                } else {
                    List {
                        switch filterMode {
                            
                        case .pending:
                            Section(header: Text("Pending Requests (\(filteredPendingRequests.count))").font(.headline).foregroundColor(.accentGreen)) {
                                if filteredPendingRequests.isEmpty { Text("No pending requests found.").foregroundColor(.textLight) }
                                ForEach(filteredPendingRequests) { request in
                                    CompactRequestRow(request: request, onApprove: {
                                        Task { await handleRequest(request, approve: true) }
                                    }, onDeny: {
                                        Task { await handleRequest(request, approve: false) }
                                    })
                                }
                            }
                            .listRowSeparator(.hidden)
                            .listRowInsets(EdgeInsets(top: 8, leading: 10, bottom: 8, trailing: 10))

                        case .active, .completed, .all:
                            Section("\(filterMode.rawValue.capitalized) Students (\(filteredApprovedStudents.count))") {
                                if filteredApprovedStudents.isEmpty { Text("No students match this filter.").foregroundColor(.textLight) }
                                ForEach(filteredApprovedStudents) { student in
                                    StudentListCard(student: student)
                                    .swipeActions(edge: .leading, allowsFullSwipe: true) {
                                        Button { Task { await startChat(with: student) } } label: { Label("Message", systemImage: "message.fill") }
                                        .tint(.primaryBlue)
                                    }
                                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                        Button(role: .destructive) { Task { await removeStudent(student) } } label: { Label("Remove", systemImage: "trash.fill") }
                                    }
                                    .listRowSeparator(.hidden)
                                    .listRowInsets(EdgeInsets(top: 8, leading: 10, bottom: 8, trailing: 10))
                                    .background(NavigationLink { StudentProfileView(student: student) } label: { EmptyView() }.opacity(0))
                                }
                            }

                        case .denied:
                            Section(header: Text("Denied Requests (\(filteredDeniedRequests.count))").font(.headline).foregroundColor(.warningRed)) {
                                if filteredDeniedRequests.isEmpty { Text("No denied requests found.").foregroundColor(.textLight) }
                                ForEach(filteredDeniedRequests) { request in
                                    CompactRequestRow(request: request, onApprove: {}, onDeny: {}, showButtons: false)
                                }
                            }
                            .listRowSeparator(.hidden)
                            .listRowInsets(EdgeInsets(top: 8, leading: 10, bottom: 8, trailing: 10))
                            
                        case .blocked:
                            Section(header: Text("Blocked Students (\(filteredBlockedRequests.count))").font(.headline).foregroundColor(Color.black)) {
                                if filteredBlockedRequests.isEmpty { Text("No blocked students found.").foregroundColor(.textLight) }
                                ForEach(filteredBlockedRequests) { request in
                                    CompactRequestRow(request: request, onApprove: {}, onDeny: {}, showButtons: false)
                                }
                            }
                            .listRowSeparator(.hidden)
                            .listRowInsets(EdgeInsets(top: 8, leading: 10, bottom: 8, trailing: 10))
                        }
                    }
                    .listStyle(.insetGrouped)
                    .animation(.default, value: filterMode)
                }
            }
            .navigationTitle("Your Students")
            .task {
                await fetchData()
            }
            .refreshable {
                await fetchData()
            }
        }
    }
    
    func fetchData() async {
        guard let instructorID = authManager.user?.id else { return }
        isLoading = true
        
        async let studentsTask = dataService.fetchStudents(for: instructorID)
        async let requestsTask = communityManager.fetchRequests(for: instructorID)
        async let deniedTask = communityManager.fetchDeniedRequests(for: instructorID)
        async let blockedTask = communityManager.fetchBlockedRequests(for: instructorID)
        
        do {
            self.approvedStudents = try await studentsTask
            self.pendingRequests = try await requestsTask
            self.deniedRequests = try await deniedTask
            self.blockedRequests = try await blockedTask
        } catch {
            print("Failed to fetch data: \(error)")
        }
        isLoading = false
    }
    
    func handleRequest(_ request: StudentRequest, approve: Bool) async {
        do {
            if approve {
                try await communityManager.approveRequest(request)
            } else {
                try await communityManager.denyRequest(request)
            }
            await fetchData()
        } catch {
            print("Failed to handle request: \(error)")
        }
    }
    
    func removeStudent(_ student: Student) async {
        guard let instructorID = authManager.user?.id, let studentID = student.id else { return }
        
        do {
            try await communityManager.removeStudent(studentID: studentID, instructorID: instructorID)
            await fetchData()
        } catch {
            print("Failed to remove student: \(error)")
        }
    }
    
    func startChat(with student: Student) async {
        guard let currentUser = authManager.user else { return }
        do {
            guard let otherUser = try await dataService.fetchUser(withId: student.id ?? "") else {
                print("Error: Could not fetch student AppUser to start chat")
                return
            }
            
            let conversation = try await chatManager.getOrCreateConversation(
                currentUser: currentUser,
                otherUser: otherUser
            )
            self.conversationToPush = conversation
        } catch {
            print("Error starting chat: \(error.localizedDescription)")
        }
    }
}

// --- UPDATED ENUM ---
enum StudentFilter: String {
    case pending = "Pending"
    case active = "Active"
    case completed = "Completed"
    case denied = "Denied"
    case blocked = "Blocked"
    case all = "All Students"
}

struct CompactRequestRow: View {
    let request: StudentRequest
    let onApprove: () -> Void
    let onDeny: () -> Void
    var showButtons: Bool = true
    
    var body: some View {
        HStack {
            AsyncImage(url: URL(string: request.studentPhotoURL ?? "")) { phase in
                if let image = phase.image {
                    image.resizable().scaledToFill()
                } else {
                    Image(systemName: "person.circle.fill")
                        .resizable()
                        .foregroundColor(.primaryBlue)
                }
            }
            .frame(width: 45, height: 45)
            .clipShape(Circle())
            
            VStack(alignment: .leading) {
                Text(request.studentName)
                    .font(.headline)
                Text("Sent \(request.timestamp.formatted(.relative(presentation: .named)))")
                    .font(.caption)
                    .foregroundColor(.textLight)
            }
            
            Spacer()
            
            if showButtons {
                HStack(spacing: 8) {
                    Button(action: onDeny) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title2)
                            .foregroundColor(.warningRed)
                    }
                    .buttonStyle(BorderlessButtonStyle())
                    
                    Button(action: onApprove) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.title2)
                            .foregroundColor(.accentGreen)
                    }
                    .buttonStyle(BorderlessButtonStyle())
                }
            } else {
                // This will no longer be ambiguous
                StatusBadge(status: request.status)
            }
        }
        .padding(10)
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: Color.textDark.opacity(0.05), radius: 5, x: 0, y: 2)
    }
}


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
