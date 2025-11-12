// File: MyInstructor/Features/Student/MyInstructorsView.swift
// --- UPDATED: "Blocked by You" instructors are now tappable to view profile for unblocking ---

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
    
    // "My Instructors" now includes active AND student-blocked instructors
    private var myInstructorsList: [StudentRequest] {
        sentRequests.filter { $0.status == .approved || ($0.status == .blocked && $0.blockedBy == "student") }
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
            VStack {
                Picker("Request Status", selection: $selectedStatus) {
                    Text("My Instructors (\(myInstructorsList.count))").tag(MyInstructorsFilter.approved)
                    Text("Pending (\(otherRequestsCount))").tag(MyInstructorsFilter.pending)
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)
                
                if isLoading {
                    ProgressView("Loading Requests...")
                        .frame(maxHeight: .infinity)
                } else {
                    if selectedStatus == .approved {
                        // --- *** THIS IS THE "MY INSTRUCTORS" (APPROVED) TAB *** ---
                        if myInstructorsList.isEmpty {
                            VStack(spacing: 15) {
                                Image(systemName: "person.badge.plus")
                                    .font(.system(size: 50))
                                    .foregroundColor(.textLight)
                                
                                Text("You have no approved or blocked instructors yet.")
                                    .font(.headline)
                                    .foregroundColor(.textLight)
                                    .multilineTextAlignment(.center)
                                    .padding(.horizontal)
                                
                                NavigationLink(destination: InstructorDirectoryView()) {
                                    Text("Find an Instructor")
                                }
                                .buttonStyle(.primaryDrivingApp)
                                .frame(width: 200)
                            }
                            .padding(40)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            
                        } else {
                            List {
                                Section("My Instructors") {
                                    // --- *** THIS IS THE UPDATED LOGIC *** ---
                                    // The row is now always a NavigationLink.
                                    ForEach(myInstructorsList) { request in
                                        NavigationLink(destination: InstructorPublicProfileView(instructorID: request.instructorID)) {
                                            MyInstructorRow(request: request)
                                        }
                                        // The swipe action changes based on the status
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
                                        // Disable navigation if blocked *by instructor* (though they're on the other tab)
                                        .disabled(request.status == .blocked && request.blockedBy == "instructor")
                                    }
                                    // --- *** END OF UPDATED LOGIC *** ---
                                }
                            }
                            .listStyle(.insetGrouped)
                        }
                    } else {
                        // --- *** THIS IS THE "PENDING" TAB *** ---
                        if otherRequestsCount == 0 {
                            EmptyStateView(
                                icon: "paperplane.fill",
                                message: "You have no pending, denied, or instructor-blocked requests."
                            )
                        } else {
                            List {
                                if !pendingRequests.isEmpty {
                                    Section("Pending Requests") {
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
                                    Section("Denied Requests") {
                                        ForEach(deniedRequests) { request in
                                            NavigationLink(destination: InstructorPublicProfileView(instructorID: request.instructorID)) {
                                                MyInstructorRow(request: request)
                                            }
                                        }
                                    }
                                }
                                if !instructorBlockedRequests.isEmpty {
                                    Section("Blocked by Instructor") {
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
            .navigationTitle("My Instructors")
            .task {
                await loadRequests()
            }
            .refreshable {
                await loadRequests()
            }
        }
    }
    
    private func loadRequests() async {
        guard let studentID = authManager.user?.id else { return }
        isLoading = true
        do {
            // 1. Fetch all requests, sorted by priority (Blocked > Approved > etc)
            let allRequests = try await communityManager.fetchSentRequests(for: studentID)
            
            // 2. De-duplicate the list to prevent "double profiles"
            var uniqueRequests: [StudentRequest] = []
            var seenInstructorIDs = Set<String>()
            
            for request in allRequests {
                // Because the list is pre-sorted, we only add the *first*
                // request we see for each instructor.
                if !seenInstructorIDs.contains(request.instructorID) {
                    uniqueRequests.append(request)
                    seenInstructorIDs.insert(request.instructorID)
                }
            }
            
            // 3. Set the de-duplicated list as our main source
            self.sentRequests = uniqueRequests
            
            // 4. Sync local profile with *only* the approved instructors
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
        } catch {
            print("Failed to cancel request: \(error.localizedDescription)")
        }
    }
    
    private func removeInstructor(_ request: StudentRequest) async {
        guard let studentID = authManager.user?.id else { return }
        do {
            try await communityManager.removeInstructor(instructorID: request.instructorID, studentID: studentID)
            // Refresh list to move them to "Denied"
            await loadRequests()
        } catch {
            print("Failed to remove instructor: \(error.localizedDescription)")
        }
    }
    
    private func unblockInstructor(_ request: StudentRequest) async {
        guard let studentID = authManager.user?.id else { return }
        do {
            try await communityManager.unblockInstructor(instructorID: request.instructorID, studentID: studentID)
            // After unblocking, refresh the list. The request will
            // move to the "Denied" section.
            await loadRequests()
        } catch {
            print("Failed to unblock instructor: \(error.localizedDescription)")
        }
    }
}

// REDESIGNED ROW
struct MyInstructorRow: View {
    @EnvironmentObject var dataService: DataService
    let request: StudentRequest
    
    @State private var instructor: AppUser?
    
    var body: some View {
        HStack(spacing: 12) {
            AsyncImage(url: URL(string: instructor?.photoURL ?? "")) { phase in
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
                if let instructor {
                    Text(instructor.name ?? "Instructor")
                        .font(.headline)
                        .foregroundColor(request.status == .blocked ? .textLight : .textDark)
                } else {
                    ProgressView()
                        .frame(maxWidth: 100)
                }
                Text(request.timestamp, style: .date)
                    .font(.caption)
                    .foregroundColor(.textLight)
            }
            
            Spacer()
            
            StatusBadge(status: request.status, blockedBy: request.blockedBy)
        }
        .padding(.vertical, 6)
        .task {
            if instructor == nil {
                do {
                    self.instructor = try await dataService.fetchUser(withId: request.instructorID)
                } catch {
                    print("Failed to fetch instructor for row: \(error)")
                }
            }
        }
    }
}


// A simple badge to show the request status
struct StatusBadge: View {
    let status: RequestStatus
    let blockedBy: String?
    
    var text: String {
        switch status {
        case .pending: return "Pending"
        case .approved: return "Approved"
        case .denied: return "Denied"
        case .blocked:
            if blockedBy == "student" {
                return "Blocked by You"
            } else if blockedBy == "instructor" {
                return "Blocked by Instructor"
            }
            return "Blocked" // Fallback
        }
    }
    
    var color: Color {
        switch status {
        case .pending: return .orange
        case .approved: return .accentGreen
        case .denied: return .warningRed
        case .blocked: return .black
        }
    }
    
    var body: some View {
        Text(text)
            .font(.caption).bold()
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(color.opacity(0.15))
            .foregroundColor(color)
            .cornerRadius(8)
    }
}
