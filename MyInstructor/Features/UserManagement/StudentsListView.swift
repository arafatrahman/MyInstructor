// File: arafatrahman/myinstructor/MyInstructor-main/MyInstructor/Features/UserManagement/StudentsListView.swift
// --- UPDATED: Default filter is .active, and Offline students are included in the Active list ---

import SwiftUI

struct StudentsListView: View {
    @EnvironmentObject var authManager: AuthManager
    @EnvironmentObject var dataService: DataService
    @EnvironmentObject var communityManager: CommunityManager
    @EnvironmentObject var chatManager: ChatManager
    
    // --- STATE ---
    @State private var approvedStudents: [Student] = []   // Stores Active
    @State private var completedStudentsList: [Student] = [] // Stores Completed
    
    @State private var pendingRequests: [StudentRequest] = []
    @State private var deniedRequests: [StudentRequest] = []
    @State private var blockedRequests: [StudentRequest] = []
    @State private var offlineStudents: [OfflineStudent] = []
    
    @State private var isLoading = true
    @State private var searchText = ""
    
    // --- UPDATED: Default to .active ---
    @State private var filterMode: StudentFilter = .active
    
    @State private var conversationToPush: Conversation? = nil
    @State private var chatErrorAlert: (isPresented: Bool, message: String) = (false, "")
    
    @State private var isAddingOfflineStudent = false
    @State private var studentToDelete: OfflineStudent? = nil
    @State private var isShowingDeleteAlert = false
    
    // --- COMPUTED PROPERTIES ---
    
    var activeOnlineStudents: [Student] {
        let list = approvedStudents
        if searchText.isEmpty { return list }
        return list.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
    }
    
    var filteredOfflineStudents: [OfflineStudent] {
        if searchText.isEmpty { return offlineStudents }
        return offlineStudents.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
    }
    
    // --- UPDATED: Merge Online Active + Offline for the "Active" view ---
    var combinedActiveStudents: [Student] {
        let online = activeOnlineStudents
        let offlineConverted = filteredOfflineStudents.map { convertToStudent($0) }
        return (online + offlineConverted).sorted { $0.name < $1.name }
    }
    
    var completedStudents: [Student] {
        let list = completedStudentsList
        if searchText.isEmpty { return list }
        return list.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
    }
    
    var filteredPendingRequests: [StudentRequest] {
        if searchText.isEmpty { return pendingRequests }
        return pendingRequests.filter { $0.studentName.localizedCaseInsensitiveContains(searchText) }
    }
    
    var filteredDeniedRequests: [StudentRequest] {
        if searchText.isEmpty { return deniedRequests }
        return deniedRequests.filter { $0.studentName.localizedCaseInsensitiveContains(searchText) }
    }
    
    var filteredBlockedRequests: [StudentRequest] {
        if searchText.isEmpty { return blockedRequests }
        return blockedRequests.filter { $0.studentName.localizedCaseInsensitiveContains(searchText) }
    }
    
    func convertToStudent(_ offline: OfflineStudent) -> Student {
        return Student(
            id: offline.id,
            userID: offline.id ?? UUID().uuidString,
            name: offline.name,
            photoURL: nil,
            email: offline.email ?? "",
            drivingSchool: nil,
            phone: offline.phone,
            address: offline.address,
            distance: nil,
            coordinate: nil,
            isOffline: true,
            averageProgress: offline.progress ?? 0.0,
            nextLessonTime: nil,
            nextLessonTopic: nil
        )
    }
    
    // --- Helper to update progress locally ---
    func updateLocalStudentProgress(id: String, progress: Double) {
        if let index = approvedStudents.firstIndex(where: { $0.id == id }) {
            approvedStudents[index].averageProgress = progress
        }
        if let index = completedStudentsList.firstIndex(where: { $0.id == id }) {
            completedStudentsList[index].averageProgress = progress
        }
        if let index = offlineStudents.firstIndex(where: { $0.id == id }) {
            offlineStudents[index].progress = progress
        }
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
                
                // Custom Header
                HStack {
                    Text("Your Students").font(.largeTitle).fontWeight(.bold)
                    Spacer()
                    Button { isAddingOfflineStudent = true } label: {
                        Image(systemName: "plus.circle.fill").font(.title).foregroundColor(.primaryBlue)
                    }
                }
                .padding(.horizontal).padding(.top, 10)
                
                HStack {
                    SearchBar(text: $searchText, placeholder: "Search students")
                    Picker("Filter", selection: $filterMode) {
                        Text("All").tag(StudentFilter.allCategories)
                        Text("Pending").tag(StudentFilter.pending)
                        Text("Active").tag(StudentFilter.active)
                        Text("Completed").tag(StudentFilter.completed)
                        Text("Denied").tag(StudentFilter.denied)
                        Text("Blocked").tag(StudentFilter.blocked)
                        Text("Offline").tag(StudentFilter.offline)
                    }
                    .pickerStyle(.menu).frame(width: 110).foregroundColor(.primaryBlue)
                }
                .padding(.horizontal)
                
                if isLoading {
                    ProgressView("Loading Students...").padding(.top, 50)
                } else if pendingRequests.isEmpty && approvedStudents.isEmpty && completedStudentsList.isEmpty && deniedRequests.isEmpty && blockedRequests.isEmpty && offlineStudents.isEmpty {
                    EmptyStateView(icon: "person.3.fill", message: "No students yet. Tap '+' to add an offline student.")
                } else {
                    List {
                        // Pending
                        if filterMode == .allCategories || filterMode == .pending {
                            Section(header: Text("Pending Requests (\(filteredPendingRequests.count))").font(.headline).foregroundColor(.accentGreen)) {
                                if filteredPendingRequests.isEmpty { Text("No pending requests.").foregroundColor(.textLight) }
                                ForEach(filteredPendingRequests) { request in
                                    CompactRequestRow(request: request, filterMode: .pending, onApprove: { Task { await handleRequest(request, approve: true) } }, onDeny: { Task { await handleRequest(request, approve: false) } }, onUnblock: {})
                                }
                            }
                            .listRowSeparator(.hidden).listRowInsets(EdgeInsets(top: 8, leading: 10, bottom: 8, trailing: 10))
                        }

                        // Active (NOW INCLUDES OFFLINE)
                        if filterMode == .allCategories || filterMode == .active {
                            Section(header: Text("Active Students (\(combinedActiveStudents.count))").font(.headline)) {
                                if combinedActiveStudents.isEmpty { Text("No active students.").foregroundColor(.textLight) }
                                
                                ForEach(combinedActiveStudents) { student in
                                    StudentListCard(student: student)
                                    .swipeActions(edge: .leading, allowsFullSwipe: true) {
                                        // Only show Message for Online Students
                                        if !student.isOffline {
                                            Button { Task { await startChat(with: student) } } label: { Label("Message", systemImage: "message.fill") }.tint(.primaryBlue)
                                        }
                                    }
                                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                        if student.isOffline {
                                            // Offline: Delete
                                            Button(role: .destructive) {
                                                // Find original offline object to delete
                                                if let original = offlineStudents.first(where: { $0.id == student.id }) {
                                                    self.studentToDelete = original
                                                    self.isShowingDeleteAlert = true
                                                }
                                            } label: { Label("Delete", systemImage: "trash.fill") }
                                        } else {
                                            // Online: Complete
                                            Button(role: .destructive) { Task { await removeStudent(student) } } label: { Label("Complete", systemImage: "checkmark.circle") }
                                        }
                                    }
                                    .listRowSeparator(.hidden).listRowInsets(EdgeInsets(top: 8, leading: 10, bottom: 8, trailing: 10))
                                    .background(NavigationLink {
                                        StudentProfileView(student: student, onProgressUpdate: { id, progress in
                                            updateLocalStudentProgress(id: id, progress: progress)
                                        })
                                    } label: { EmptyView() }.opacity(0))
                                }
                            }
                        }
                        
                        // Completed (Past Students)
                        if filterMode == .allCategories || filterMode == .completed {
                            Section(header: Text("Completed Students (\(completedStudents.count))").font(.headline).foregroundColor(.textLight)) {
                                if completedStudents.isEmpty { Text("No completed students.").foregroundColor(.textLight) }
                                ForEach(completedStudents) { student in
                                    StudentListCard(student: student)
                                    .swipeActions(edge: .leading, allowsFullSwipe: false) {
                                        Button { Task { await reactivateStudent(student) } } label: { Label("Add Again", systemImage: "person.badge.plus") }.tint(.accentGreen)
                                    }
                                    .listRowSeparator(.hidden).listRowInsets(EdgeInsets(top: 8, leading: 10, bottom: 8, trailing: 10))
                                    .background(NavigationLink {
                                        StudentProfileView(student: student, onProgressUpdate: { id, progress in
                                            updateLocalStudentProgress(id: id, progress: progress)
                                        })
                                    } label: { EmptyView() }.opacity(0))
                                }
                            }
                        }

                        // Denied & Blocked
                        if filterMode == .allCategories || filterMode == .denied {
                            Section(header: Text("Denied (\(filteredDeniedRequests.count))").font(.headline).foregroundColor(.warningRed)) {
                                ForEach(filteredDeniedRequests) { request in CompactRequestRow(request: request, filterMode: .denied, onApprove: { Task { await handleRequest(request, approve: true) } }, onDeny: {}, onUnblock: {}) }
                            }
                            .listRowSeparator(.hidden).listRowInsets(EdgeInsets(top: 8, leading: 10, bottom: 8, trailing: 10))
                        }
                        if filterMode == .allCategories || filterMode == .blocked {
                            Section(header: Text("Blocked (\(filteredBlockedRequests.count))").font(.headline)) {
                                ForEach(filteredBlockedRequests) { request in CompactRequestRow(request: request, filterMode: .blocked, onApprove: {}, onDeny: {}, onUnblock: { Task { await unblockStudent(request) } }) }
                            }
                            .listRowSeparator(.hidden).listRowInsets(EdgeInsets(top: 8, leading: 10, bottom: 8, trailing: 10))
                        }
                        
                        // Offline (Specific Category)
                        // Only show if specifically selected, or if 'All' is selected (to avoid duplication if user wants to see *just* offline)
                        // However, user requested offline in Active.
                        // Typically, if they are in Active, we might not need a separate Offline section in 'Active' mode,
                        // but if filterMode == .offline we show them.
                        // If filterMode == .allCategories, they will appear in Active.
                        if filterMode == .offline {
                            Section(header: Text("Offline Students (\(filteredOfflineStudents.count))").font(.headline).foregroundColor(.gray)) {
                                if filteredOfflineStudents.isEmpty { Text("No offline students.").foregroundColor(.textLight) }
                                ForEach(filteredOfflineStudents) { offlineStudent in
                                    let convertedStudent = convertToStudent(offlineStudent)
                                    StudentListCard(student: convertedStudent)
                                        .swipeActions(edge: .trailing) {
                                            Button(role: .destructive) {
                                                self.studentToDelete = offlineStudent
                                                self.isShowingDeleteAlert = true
                                            } label: { Label("Delete", systemImage: "trash.fill") }
                                        }
                                        .listRowSeparator(.hidden).listRowInsets(EdgeInsets(top: 8, leading: 10, bottom: 8, trailing: 10))
                                        .background(NavigationLink {
                                            StudentProfileView(student: convertedStudent, onProgressUpdate: { id, progress in
                                                updateLocalStudentProgress(id: id, progress: progress)
                                            })
                                        } label: { EmptyView() }.opacity(0))
                                }
                            }
                        }
                    }
                    .listStyle(.insetGrouped)
                    .animation(.default, value: filterMode)
                }
            }
            .navigationBarHidden(true)
            .task { await fetchData() }
            .refreshable { await fetchData() }
            .onAppear {
                Task { await fetchData() }
            }
            .sheet(isPresented: $isAddingOfflineStudent) { OfflineStudentFormView(studentToEdit: nil, onStudentAdded: { Task { await fetchData() } }) }
            .alert("Cannot Start Chat", isPresented: $chatErrorAlert.isPresented, actions: { Button("OK") { } }, message: { Text(chatErrorAlert.message) })
            .alert("Delete Student?", isPresented: $isShowingDeleteAlert, presenting: studentToDelete) { student in
                Button("Cancel", role: .cancel) { studentToDelete = nil }
                Button("Delete", role: .destructive) {
                    if let studentID = student.id { Task { await performDelete(studentID: studentID) } }
                    studentToDelete = nil
                }
            } message: { student in Text("Are you sure you want to delete \(student.name)?") }
        }
    }
    
    // MARK: - Data Fetching
    func fetchData() async {
        guard let instructorID = authManager.user?.id else { return }
        
        // Show loading only if we have NO data yet to prevent flickering on refresh
        if approvedStudents.isEmpty && completedStudentsList.isEmpty && pendingRequests.isEmpty && offlineStudents.isEmpty {
            isLoading = true
        }
        
        do {
            // 1. Fetch Requests
            let allRequests = try await communityManager.fetchAllRelationships(for: instructorID)
            self.pendingRequests = allRequests.filter { $0.status == .pending }
            self.deniedRequests = allRequests.filter { $0.status == .denied }
            self.blockedRequests = allRequests.filter { $0.status == .blocked }
            
            let activeIDs = allRequests.filter { $0.status == .approved }.map { $0.studentID }
            let completedIDs = allRequests.filter { $0.status == .completed }.map { $0.studentID }
            
            // 2. Fetch User Profiles & Progress
            // dataService.fetchStudents now gets the latest progress via student_records
            let allProfileIDs = activeIDs + completedIDs
            let profiles = try await dataService.fetchStudents(fromIDs: allProfileIDs, instructorID: instructorID)
            
            // 3. Assign
            self.approvedStudents = profiles.filter { activeIDs.contains($0.id ?? "") }
            self.completedStudentsList = profiles.filter { completedIDs.contains($0.id ?? "") }
            
            // 4. Offline Students (Fetches fresh documents with latest progress)
            self.offlineStudents = try await dataService.fetchOfflineStudents(for: instructorID)
            
        } catch {
            print("Failed to fetch data: \(error)")
        }
        isLoading = false
    }
    
    func performDelete(studentID: String) async {
        do {
            try await communityManager.deleteOfflineStudent(studentID: studentID)
            offlineStudents.removeAll(where: { $0.id == studentID })
        } catch { print("Failed to delete offline student: \(error)") }
    }
    
    func handleRequest(_ request: StudentRequest, approve: Bool) async {
        do {
            if approve { try await communityManager.approveRequest(request) }
            else { try await communityManager.denyRequest(request) }
            await fetchData()
        } catch { print("Failed to handle request: \(error)") }
    }
    
    func removeStudent(_ student: Student) async {
        guard let instructorID = authManager.user?.id, let studentID = student.id else { return }
        try? await communityManager.removeStudent(studentID: studentID, instructorID: instructorID)
        await fetchData()
    }
    
    func reactivateStudent(_ student: Student) async {
        guard let instructorID = authManager.user?.id, let studentID = student.id else { return }
        try? await communityManager.reactivateStudent(studentID: studentID, instructorID: instructorID)
        await fetchData()
    }
    
    func unblockStudent(_ request: StudentRequest) async {
        guard let instructorID = authManager.user?.id else { return }
        try? await communityManager.unblockStudent(studentID: request.studentID, instructorID: instructorID)
        await fetchData()
    }
    
    func startChat(with student: Student) async {
        guard let currentUser = authManager.user else { return }
        do {
            guard let otherUser = try await dataService.fetchUser(withId: student.id ?? "") else { return }
            let conversation = try await chatManager.getOrCreateConversation(currentUser: currentUser, otherUser: otherUser)
            self.conversationToPush = conversation
        } catch let error as ChatError { self.chatErrorAlert = (true, error.localizedDescription) }
        catch { self.chatErrorAlert = (true, error.localizedDescription) }
    }
}

// --- Helper Enum & Views ---

enum StudentFilter: String {
    case allCategories = "All", pending = "Pending", active = "Active", completed = "Completed", denied = "Denied", blocked = "Blocked", offline = "Offline"
}

struct CompactRequestRow: View {
    let request: StudentRequest
    let filterMode: StudentFilter
    let onApprove: () -> Void
    let onDeny: () -> Void
    let onUnblock: () -> Void
    
    var body: some View {
        HStack {
            // Updated Avatar using DefaultAvatar logic inlined
            if let urlString = request.studentPhotoURL, let url = URL(string: urlString) {
                AsyncImage(url: url) { phase in
                    if let image = phase.image { image.resizable().scaledToFill() }
                    else {
                        Circle().fill(Color.primaryBlue.opacity(0.1))
                            .overlay(Text(request.studentName.prefix(1)).bold().foregroundColor(.primaryBlue))
                    }
                }
                .frame(width: 45, height: 45).clipShape(Circle())
            } else {
                ZStack {
                    Circle().fill(Color.primaryBlue.opacity(0.1))
                    Text(request.studentName.prefix(1).uppercased()).font(.title3).bold().foregroundColor(.primaryBlue)
                }
                .frame(width: 45, height: 45)
            }
            
            VStack(alignment: .leading) {
                Text(request.studentName).font(.headline)
                Text("Sent \(request.timestamp.formatted(.relative(presentation: .named)))").font(.caption).foregroundColor(.textLight)
            }
            Spacer()
            
            switch filterMode {
            case .pending:
                HStack(spacing: 8) {
                    Button(action: onDeny) { Image(systemName: "xmark.circle.fill").font(.title2).foregroundColor(.warningRed) }.buttonStyle(BorderlessButtonStyle())
                    Button(action: onApprove) { Image(systemName: "checkmark.circle.fill").font(.title2).foregroundColor(.accentGreen) }.buttonStyle(BorderlessButtonStyle())
                }
            case .blocked:
                Button(action: onUnblock) { Text("Unblock").font(.caption).bold().padding(6).background(Color.accentGreen.opacity(0.15)).foregroundColor(.accentGreen).cornerRadius(8) }.buttonStyle(BorderlessButtonStyle())
            case .denied:
                Button(action: onApprove) { Text("Approve").font(.caption).bold().padding(6).background(Color.accentGreen.opacity(0.15)).foregroundColor(.accentGreen).cornerRadius(8) }.buttonStyle(BorderlessButtonStyle())
            default: EmptyView()
            }
        }
        .padding(10).background(Color(.systemBackground)).cornerRadius(12).shadow(color: Color.textDark.opacity(0.05), radius: 5, x: 0, y: 2)
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
    
    // --- Helper for Initials ---
    var initials: String {
        let components = student.name.split(separator: " ")
        let first = components.first?.prefix(1) ?? ""
        let second = components.dropFirst().first?.prefix(1) ?? ""
        return "\(first)\(second)".uppercased()
    }

    var body: some View {
        HStack {
            CircularProgressView(progress: student.averageProgress, color: progressColor, size: 50)
                .overlay(
                    Group {
                        if let urlString = student.photoURL, let url = URL(string: urlString) {
                            AsyncImage(url: url) { phase in
                                if let image = phase.image {
                                    image.resizable().scaledToFill()
                                } else {
                                    // Fallback if URL exists but image fails to load
                                    ZStack {
                                        Circle().fill(Color(.systemGray5))
                                        Text(initials).font(.caption).bold().foregroundColor(progressColor)
                                    }
                                }
                            }
                        } else {
                            // Default Avatar for Offline/No Photo
                            ZStack {
                                Circle().fill(Color(.systemGray5))
                                Text(initials)
                                    .font(.caption)
                                    .fontWeight(.bold)
                                    .foregroundColor(progressColor) // Use progress color for text
                            }
                        }
                    }
                    .clipShape(Circle())
                    .frame(width: 45, height: 45)
                )
                .frame(width: 50, height: 50)
            
            VStack(alignment: .leading) {
                Text(student.name).font(.headline)
                HStack {
                    Image(systemName: student.nextLessonTime != nil ? "clock.fill" : "calendar.badge.exclamationmark").font(.caption)
                    Text(nextLessonTimeString).font(.caption)
                }.foregroundColor(.textLight)
            }
            Spacer()
            
            VStack(alignment: .trailing) {
                Text("\(Int(student.averageProgress * 100))%").font(.title3).bold().foregroundColor(progressColor)
                Text("Mastery").font(.caption).foregroundColor(.textLight)
            }
        }
        .padding(10).background(Color(.systemBackground)).cornerRadius(12).shadow(color: Color.textDark.opacity(0.05), radius: 5, x: 0, y: 2)
    }
}
