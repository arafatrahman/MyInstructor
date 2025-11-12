// File: MyInstructor/Features/Student/MyInstructorsView.swift
// --- UPDATED: Added swipe-to-unblock and clearer status badges ---

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
    
    private var approvedRequests: [StudentRequest] {
        sentRequests.filter { $0.status == .approved }
    }
    
    private var pendingRequests: [StudentRequest] {
        sentRequests.filter { $0.status == .pending }
    }
    
    private var deniedRequests: [StudentRequest] {
        sentRequests.filter { $0.status == .denied }
    }
    
    private var blockedRequests: [StudentRequest] {
        sentRequests.filter { $0.status == .blocked }
    }
    
    var body: some View {
        NavigationView {
            VStack {
                Picker("Request Status", selection: $selectedStatus) {
                    Text("My Instructors (\(approvedRequests.count))").tag(MyInstructorsFilter.approved)
                    Text("Pending (\(pendingRequests.count + deniedRequests.count + blockedRequests.count))").tag(MyInstructorsFilter.pending) // Updated count
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)
                
                if isLoading {
                    ProgressView("Loading Requests...")
                        .frame(maxHeight: .infinity)
                } else {
                    if selectedStatus == .approved {
                        if approvedRequests.isEmpty {
                            VStack(spacing: 15) {
                                Image(systemName: "person.badge.plus")
                                    .font(.system(size: 50))
                                    .foregroundColor(.textLight)
                                
                                Text("You have no approved instructors yet.")
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
                                Section("Approved Instructors") {
                                    ForEach(approvedRequests) { request in
                                        NavigationLink(destination: InstructorPublicProfileView(instructorID: request.instructorID)) {
                                            MyInstructorRow(request: request)
                                        }
                                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                            Button(role: .destructive) {
                                                Task { await removeInstructor(request) }
                                            } label: {
                                                Label("Remove", systemImage: "trash.fill")
                                            }
                                        }
                                    }
                                }
                            }
                            .listStyle(.insetGrouped)
                        }
                    } else {
                        if pendingRequests.isEmpty && deniedRequests.isEmpty && blockedRequests.isEmpty {
                            EmptyStateView(
                                icon: "paperplane.fill",
                                message: "You have no pending, denied, or blocked requests."
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
                                if !blockedRequests.isEmpty {
                                    Section("Blocked Requests") {
                                        ForEach(blockedRequests) { request in
                                            MyInstructorRow(request: request)
                                                // --- *** THIS IS THE NEW SWIPE ACTION *** ---
                                                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                                    // Only show Unblock if student blocked them
                                                    if request.blockedBy == "student" {
                                                        Button("Unblock") {
                                                            Task { await unblockInstructor(request) }
                                                        }
                                                        .tint(.accentGreen)
                                                    }
                                                }
                                                // --- *** END OF NEW SWIPE ACTION *** ---
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
            self.sentRequests = try await communityManager.fetchSentRequests(for: studentID)
            
            // --- SYNC LOCAL PROFILE ---
            let approvedIDs = self.approvedRequests.map { $0.instructorID }
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
            sentRequests.removeAll(where: { $0.id == request.id })
        } catch {
            print("Failed to remove instructor: \(error.localizedDescription)")
        }
    }
    
    // --- *** THIS IS THE NEW FUNCTION *** ---
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
                } else {
                    ProgressView()
                        .frame(maxWidth: 100)
                }
                Text(request.timestamp, style: .date)
                    .font(.caption)
                    .foregroundColor(.textLight)
            }
            
            Spacer()
            
            // --- *** UPDATED: Pass blockedBy to the badge *** ---
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
    // --- *** ADDED THIS FIELD *** ---
    let blockedBy: String?
    
    var text: String {
        switch status {
        case .pending: return "Pending"
        case .approved: return "Approved"
        case .denied: return "Denied"
        case .blocked:
            // --- *** UPDATED LOGIC *** ---
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
