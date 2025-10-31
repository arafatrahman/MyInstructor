// File: MyInstructor/Features/Student/MyInstructorsView.swift
// --- UPDATED: Now syncs approved instructors with AuthManager ---

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
    
    var body: some View {
        NavigationView {
            VStack {
                Picker("Request Status", selection: $selectedStatus) {
                    Text("My Instructors (\(approvedRequests.count))").tag(MyInstructorsFilter.approved)
                    Text("Pending (\(pendingRequests.count))").tag(MyInstructorsFilter.pending)
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
                                            MyInstructorRow(request: request, onCancel: nil)
                                        }
                                    }
                                }
                            }
                            .listStyle(.insetGrouped)
                        }
                    } else {
                        if pendingRequests.isEmpty && deniedRequests.isEmpty {
                            EmptyStateView(
                                icon: "paperplane.fill",
                                message: "You have no pending or denied requests."
                            )
                        } else {
                            List {
                                if !pendingRequests.isEmpty {
                                    Section("Pending Requests") {
                                        ForEach(pendingRequests) { request in
                                            MyInstructorRow(request: request, onCancel: {
                                                Task { await cancelRequest(request) }
                                            })
                                        }
                                    }
                                }
                                if !deniedRequests.isEmpty {
                                    Section("Denied Requests") {
                                        ForEach(deniedRequests) { request in
                                            NavigationLink(destination: InstructorPublicProfileView(instructorID: request.instructorID)) {
                                                MyInstructorRow(request: request, onCancel: nil)
                                            }
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
            
            // --- *** THIS IS THE NEW LOGIC *** ---
            // After loading, get all approved IDs
            let approvedIDs = self.approvedRequests.map { $0.instructorID }
            // Tell AuthManager to sync this list with the student's profile
            await authManager.syncApprovedInstructors(approvedInstructorIDs: approvedIDs)
            // --- *** END OF NEW LOGIC *** ---
            
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
}

// This helper view loads the instructor's details
struct MyInstructorRow: View {
    @EnvironmentObject var dataService: DataService
    let request: StudentRequest
    
    var onCancel: (() -> Void)?
    
    @State private var instructor: AppUser?
    
    var body: some View {
        VStack(alignment: .leading) {
            NavigationLink(destination: InstructorPublicProfileView(instructorID: request.instructorID)) {
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
                    
                    StatusBadge(status: request.status)
                }
            }
            .disabled(request.status == .pending) // Disable nav link for pending
            
            if request.status == .pending, let onCancel {
                Button("Cancel Request", role: .destructive, action: onCancel)
                    .font(.caption)
                    .padding(.top, 8)
                    .buttonStyle(BorderlessButtonStyle())
            }
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
