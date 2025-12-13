// File: arafatrahman/myinstructor/MyInstructor-main/MyInstructor/Features/Student/MyInstructorsView.swift
// --- UPDATED: Added "Add" (+) button to the toolbar to find instructors ---

import SwiftUI

enum MyInstructorsFilter {
    case approved, pending
}

struct MyInstructorsView: View {
    @EnvironmentObject var authManager: AuthManager
    @EnvironmentObject var communityManager: CommunityManager
    
    @State private var sentRequests: [StudentRequest] = []
    @State private var isLoading = true
    
    @State private var selectedStatus: MyInstructorsFilter = .approved
    
    // --- Navigation State ---
    @State private var showDirectory = false
    
    // "My Instructors" now includes active AND student-blocked instructors
    private var myInstructorsList: [StudentRequest] {
        sentRequests.filter { $0.status == .approved || ($0.status == .blocked && $0.blockedBy == "student") }
    }
    
    // Completed (Past) Instructors
    private var completedList: [StudentRequest] {
        sentRequests.filter { $0.status == .completed }
    }
    
    private var pendingRequests: [StudentRequest] {
        sentRequests.filter { $0.status == .pending }
    }
    
    private var deniedRequests: [StudentRequest] {
        sentRequests.filter { $0.status == .denied }
    }
    
    // This list now *only* shows instructors who blocked the student
    private var instructorBlockedRequests: [StudentRequest] {
        sentRequests.filter { $0.status == .blocked && $0.blockedBy == "instructor" }
    }
    
    // Count for the "Pending" tab
    private var otherRequestsCount: Int {
        pendingRequests.count + deniedRequests.count + instructorBlockedRequests.count
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                Color(.systemGroupedBackground) // Light gray background
                    .ignoresSafeArea()
                
                // --- Invisible Navigation Link triggered by toolbar button ---
                NavigationLink(isActive: $showDirectory, destination: {
                    InstructorDirectoryView()
                }, label: { EmptyView() })
                
                VStack(spacing: 0) {
                    // Segmented Control Container
                    VStack {
                        Picker("Request Status", selection: $selectedStatus) {
                            Text("Instructors").tag(MyInstructorsFilter.approved)
                            Text("Pending (\(otherRequestsCount))").tag(MyInstructorsFilter.pending)
                        }
                        .pickerStyle(.segmented)
                        .padding(.vertical, 10)
                        .padding(.horizontal)
                    }
                    .background(Color(.systemBackground)) // White background for picker area
                    
                    if isLoading {
                        Spacer()
                        ProgressView("Loading Requests...")
                        Spacer()
                    } else {
                        if selectedStatus == .approved {
                            // --- APPROVED TAB ---
                            if myInstructorsList.isEmpty && completedList.isEmpty {
                                EmptyStateView(
                                    icon: "person.badge.plus",
                                    message: "You haven't connected with any instructors yet.",
                                    actionTitle: "Find an Instructor",
                                    action: {
                                        showDirectory = true
                                    }
                                )
                            } else {
                                List {
                                    // 1. Active Connections
                                    if !myInstructorsList.isEmpty {
                                        Section(header: Text("Active Connections")) {
                                            ForEach(myInstructorsList) { request in
                                                ZStack {
                                                    // Navigation Link
                                                    NavigationLink(destination: InstructorPublicProfileView(instructorID: request.instructorID)) {
                                                        EmptyView()
                                                    }
                                                    .opacity(0)
                                                    
                                                    // Custom Row Content
                                                    MyInstructorRow(request: request)
                                                }
                                                .listRowInsets(EdgeInsets(top: 10, leading: 16, bottom: 10, trailing: 16))
                                                // Swipe Actions
                                                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                                    if request.status == .approved {
                                                        Button(role: .destructive) {
                                                            Task { await removeInstructor(request) }
                                                        } label: {
                                                            Label("Remove", systemImage: "trash.fill")
                                                        }
                                                    } else if request.status == .blocked && request.blockedBy == "student" {
                                                        Button("Unblock") {
                                                            Task { await unblockInstructor(request) }
                                                        }
                                                        .tint(.accentGreen)
                                                    }
                                                }
                                            }
                                        }
                                    }
                                    
                                    // 2. Past Instructors (Completed)
                                    if !completedList.isEmpty {
                                        Section(header: Text("Past Instructors")) {
                                            ForEach(completedList) { request in
                                                ZStack {
                                                    NavigationLink(destination: InstructorPublicProfileView(instructorID: request.instructorID)) {
                                                        EmptyView()
                                                    }
                                                    .opacity(0)
                                                    
                                                    MyInstructorRow(request: request)
                                                        .grayscale(1.0) // Grey out visually
                                                        .opacity(0.8)
                                                }
                                                .listRowInsets(EdgeInsets(top: 10, leading: 16, bottom: 10, trailing: 16))
                                            }
                                        }
                                    }
                                }
                                .listStyle(.insetGrouped) // Modern iOS card style
                            }
                        } else {
                            // --- PENDING TAB ---
                            if otherRequestsCount == 0 {
                                EmptyStateView(
                                    icon: "tray",
                                    message: "No pending or denied requests."
                                )
                            } else {
                                List {
                                    if !pendingRequests.isEmpty {
                                        Section(header: Text("Pending Approval")) {
                                            ForEach(pendingRequests) { request in
                                                MyInstructorRow(request: request)
                                                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                                        Button(role: .destructive) {
                                                            Task { await cancelRequest(request) }
                                                        } label: {
                                                            Label("Cancel", systemImage: "xmark.fill")
                                                        }
                                                    }
                                            }
                                        }
                                    }
                                    
                                    if !deniedRequests.isEmpty {
                                        Section(header: Text("Denied")) {
                                            ForEach(deniedRequests) { request in
                                                MyInstructorRow(request: request)
                                            }
                                        }
                                    }
                                    
                                    if !instructorBlockedRequests.isEmpty {
                                        Section(header: Text("Unavailable")) {
                                            ForEach(instructorBlockedRequests) { request in
                                                MyInstructorRow(request: request)
                                            }
                                        }
                                    }
                                }
                                .listStyle(.insetGrouped)
                            }
                        }
                    }
                }
            }
            .navigationTitle("My Instructors")
            .navigationBarTitleDisplayMode(.inline)
            // --- ADDED: Toolbar with Add Button ---
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showDirectory = true
                    } label: {
                        Image(systemName: "plus")
                            .font(.headline)
                            .foregroundColor(.primaryBlue)
                    }
                }
            }
            .task {
                await loadRequests()
            }
            .refreshable {
                await loadRequests()
            }
        }
    }
    
    // MARK: - Logic
    private func loadRequests() async {
        guard let studentID = authManager.user?.id else { return }
        isLoading = true
        do {
            let allRequests = try await communityManager.fetchSentRequests(for: studentID)
            var uniqueRequests: [StudentRequest] = []
            var seenInstructorIDs = Set<String>()
            
            for request in allRequests {
                if !seenInstructorIDs.contains(request.instructorID) {
                    uniqueRequests.append(request)
                    seenInstructorIDs.insert(request.instructorID)
                }
            }
            self.sentRequests = uniqueRequests
            
            let approvedIDs = self.myInstructorsList
                .filter { $0.status == .approved }
                .map { $0.instructorID }
            
            await authManager.syncApprovedInstructors(approvedInstructorIDs: approvedIDs)
            
        } catch {
            print("Failed to fetch sent requests: \(error)")
        }
        isLoading = false
    }
    
    private func cancelRequest(_ request: StudentRequest) async {
        guard let requestID = request.id else { return }
        do {
            try await communityManager.cancelRequest(requestID: requestID)
            sentRequests.removeAll(where: { $0.id == requestID })
        } catch { print("Failed: \(error)") }
    }
    
    private func removeInstructor(_ request: StudentRequest) async {
        guard let studentID = authManager.user?.id else { return }
        do {
            try await communityManager.removeInstructor(instructorID: request.instructorID, studentID: studentID)
            await loadRequests()
        } catch { print("Failed: \(error)") }
    }
    
    private func unblockInstructor(_ request: StudentRequest) async {
        guard let studentID = authManager.user?.id else { return }
        do {
            try await communityManager.unblockInstructor(instructorID: request.instructorID, studentID: studentID)
            await loadRequests()
        } catch { print("Failed: \(error)") }
    }
}

// MARK: - Redesigned Instructor Row Card

struct MyInstructorRow: View {
    @EnvironmentObject var dataService: DataService
    let request: StudentRequest
    
    @State private var instructor: AppUser?
    
    var body: some View {
        HStack(spacing: 15) {
            // 1. Profile Image
            AsyncImage(url: URL(string: instructor?.photoURL ?? "")) { phase in
                if let image = phase.image {
                    image
                        .resizable()
                        .scaledToFill()
                } else {
                    Image(systemName: "person.circle.fill")
                        .resizable()
                        .foregroundColor(.primaryBlue)
                }
            }
            .frame(width: 55, height: 55)
            .clipShape(Circle())
            .overlay(Circle().stroke(Color(.systemGray5), lineWidth: 1))
            
            // 2. Info Stack
            VStack(alignment: .leading, spacing: 4) {
                if let instructor = instructor {
                    Text(instructor.name ?? "Instructor")
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    if let school = instructor.drivingSchool, !school.isEmpty {
                        Text(school)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    } else {
                        Text("Independent Instructor")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                } else {
                    Text("Loading...")
                        .font(.headline)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            // 3. Status Badge & Chevron
            VStack(alignment: .trailing, spacing: 4) {
                StatusBadge(status: request.status, blockedBy: request.blockedBy)
                
                Text(request.timestamp.formatted(date: .abbreviated, time: .omitted))
                    .font(.caption2)
                    .foregroundColor(.tertiaryLabel)
            }
        }
        .padding(.vertical, 4)
        .task {
            if instructor == nil {
                do {
                    self.instructor = try await dataService.fetchUser(withId: request.instructorID)
                } catch {
                    print("Failed to fetch instructor: \(error)")
                }
            }
        }
    }
}

// Reusing your StatusBadge, tweaked for look
struct StatusBadge: View {
    let status: RequestStatus
    let blockedBy: String?
    
    var config: (text: String, color: Color) {
        switch status {
        case .pending: return ("Pending", .orange)
        case .approved: return ("Approved", .accentGreen)
        case .denied: return ("Denied", .warningRed)
        case .completed: return ("Past", .gray)
        case .blocked:
            return (blockedBy == "student" ? "Blocked" : "Unavailable", .gray)
        }
    }
    
    var body: some View {
        Text(config.text)
            .font(.system(size: 10, weight: .bold))
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(config.color.opacity(0.15))
            .foregroundColor(config.color)
            .cornerRadius(12)
    }
}

// Helper color for tertiary text
extension Color {
    static let tertiaryLabel = Color(UIColor.tertiaryLabel)
}
