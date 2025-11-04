// File: arafatrahman/myinstructor/MyInstructor-main/MyInstructor/Features/UserManagement/StudentsListView.swift
// --- UPDATED: Default filter is now "All Categories", showing all sections ---

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
    // --- THIS IS THE CHANGE ---
    @State private var filterMode: StudentFilter = .allCategories // New default
    
    @State private var conversationToPush: Conversation? = nil
    @State private var chatErrorAlert: (isPresented: Bool, message: String) = (false, "")
    
    // --- UPDATED: Split 'filteredApprovedStudents' into two new properties ---
    var activeStudents: [Student] {
        let list = approvedStudents.filter { $0.averageProgress < 1.0 }
        if searchText.isEmpty { return list }
        return list.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
    }
    
    var completedStudents: [Student] {
        let list = approvedStudents.filter { $0.averageProgress >= 1.0 }
        if searchText.isEmpty { return list }
        return list.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
    }
    // --- END OF CHANGE ---
    
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
                    
                    // --- UPDATED PICKER ---
                    Picker("Filter", selection: $filterMode) {
                        Text("All Categories").tag(StudentFilter.allCategories)
                        Text("Pending").tag(StudentFilter.pending)
                        Text("Active").tag(StudentFilter.active)
                        Text("Completed").tag(StudentFilter.completed)
                        Text("Denied").tag(StudentFilter.denied)
                        Text("Blocked").tag(StudentFilter.blocked)
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
                    // --- UPDATED: Removed 'switch' and now use 'if' to show sections ---
                    List {
                        
                        if filterMode == .allCategories || filterMode == .pending {
                            Section(header: Text("Pending Requests (\(filteredPendingRequests.count))").font(.headline).foregroundColor(.accentGreen)) {
                                if filteredPendingRequests.isEmpty { Text("No pending requests found.").foregroundColor(.textLight) }
                                ForEach(filteredPendingRequests) { request in
                                    CompactRequestRow(request: request, filterMode: .pending, onApprove: {
                                        Task { await handleRequest(request, approve: true) }
                                    }, onDeny: {
                                        Task { await handleRequest(request, approve: false) }
                                    }, onUnblock: {})
                                }
                            }
                            .listRowSeparator(.hidden)
                            .listRowInsets(EdgeInsets(top: 8, leading: 10, bottom: 8, trailing: 10))
                        }

                        if filterMode == .allCategories || filterMode == .active {
                            Section(header: Text("Active Students (\(activeStudents.count))").font(.headline)) {
                                if activeStudents.isEmpty { Text("No active students found.").foregroundColor(.textLight) }
                                ForEach(activeStudents) { student in
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
                        }
                        
                        if filterMode == .allCategories || filterMode == .completed {
                            Section(header: Text("Completed Students (\(completedStudents.count))").font(.headline).foregroundColor(.textLight)) {
                                if completedStudents.isEmpty { Text("No completed students found.").foregroundColor(.textLight) }
                                ForEach(completedStudents) { student in
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
                        }

                        if filterMode == .allCategories || filterMode == .denied {
                            Section(header: Text("Denied Requests (\(filteredDeniedRequests.count))").font(.headline).foregroundColor(.warningRed)) {
                                if filteredDeniedRequests.isEmpty { Text("No denied requests found.").foregroundColor(.textLight) }
                                ForEach(filteredDeniedRequests) { request in
                                    CompactRequestRow(request: request, filterMode: .denied, onApprove: {
                                        Task { await handleRequest(request, approve: true) }
                                    }, onDeny: {}, onUnblock: {})
                                }
                            }
                            .listRowSeparator(.hidden)
                            .listRowInsets(EdgeInsets(top: 8, leading: 10, bottom: 8, trailing: 10))
                        }
                            
                        if filterMode == .allCategories || filterMode == .blocked {
                            Section(header: Text("Blocked Students (\(filteredBlockedRequests.count))").font(.headline).foregroundColor(Color.black)) {
                                if filteredBlockedRequests.isEmpty { Text("No blocked students found.").foregroundColor(.textLight) }
                                ForEach(filteredBlockedRequests) { request in
                                    CompactRequestRow(request: request, filterMode: .blocked, onApprove: {}, onDeny: {}, onUnblock: {
                                        Task { await unblockStudent(request) }
                                    })
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
            // Alert for chat errors (like being blocked)
            .alert("Cannot Start Chat", isPresented: $chatErrorAlert.isPresented, actions: {
                Button("OK") { }
            }, message: {
                Text(chatErrorAlert.message)
            })
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
    
    func unblockStudent(_ request: StudentRequest) async {
        guard let instructorID = authManager.user?.id else { return }
        do {
            try await communityManager.unblockStudent(studentID: request.studentID, instructorID: instructorID)
            await fetchData() // Refresh all lists
        } catch {
            print("Failed to unblock student: \(error)")
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
        } catch let error as ChatError {
             print("Chat blocked: \(error.localizedDescription)")
             self.chatErrorAlert = (true, error.localizedDescription)
        } catch {
            print("Error starting chat: \(error.localizedDescription)")
            self.chatErrorAlert = (true, error.localizedDescription)
        }
    }
}

// --- UPDATED ENUM ---
enum StudentFilter: String {
    case allCategories = "All"
    case pending = "Pending"
    case active = "Active"
    case completed = "Completed"
    case denied = "Denied"
    case blocked = "Blocked"
}

struct CompactRequestRow: View {
    let request: StudentRequest
    let filterMode: StudentFilter
    let onApprove: () -> Void
    let onDeny: () -> Void
    let onUnblock: () -> Void
    
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
            
            switch filterMode {
            case .pending:
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
            case .blocked:
                Button(action: onUnblock) {
                    Text("Unblock")
                        .font(.caption).bold()
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.accentGreen.opacity(0.15))
                        .foregroundColor(.accentGreen)
                        .cornerRadius(8)
                }
                .buttonStyle(BorderlessButtonStyle())
            
            case .denied:
                Button(action: onApprove) {
                    Text("Approve")
                        .font(.caption).bold()
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.accentGreen.opacity(0.15))
                        .foregroundColor(.accentGreen)
                        .cornerRadius(8)
                }
                .buttonStyle(BorderlessButtonStyle())
                
            default:
                EmptyView()
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
