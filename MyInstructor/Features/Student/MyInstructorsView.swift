// File: MyInstructor/Features/Student/MyInstructorsView.swift
// --- UPDATED: Removed button and made rows into NavigationLinks ---

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
    
    // --- NEW: A list for "Denied" requests ---
    private var deniedRequests: [StudentRequest] {
        sentRequests.filter { $0.status == .denied }
    }
    
    var body: some View {
        NavigationView {
            VStack {
                Picker("Request Status", selection: $selectedStatus) {
                    Text("My Instructors (\(approvedRequests.count))").tag(MyInstructorsFilter.approved)
                    // The tab title now only counts pending requests
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
                                        // --- *** THIS IS THE FIX *** ---
                                        NavigationLink(destination: InstructorPublicProfileView(instructorID: request.instructorID)) {
                                            MyInstructorRow(request: request)
                                        }
                                        // --- *** END OF FIX *** ---
                                    }
                                }
                            }
                            .listStyle(.insetGrouped)
                        }
                    } else {
                        // This 'if' now checks the new 'pendingRequests' list
                        if pendingRequests.isEmpty && deniedRequests.isEmpty {
                            EmptyStateView(
                                icon: "paperplane.fill",
                                message: "You have no pending or denied requests." // Updated message
                            )
                        } else {
                            List {
                                // --- Section for Pending ---
                                if !pendingRequests.isEmpty {
                                    Section("Pending Requests") {
                                        ForEach(pendingRequests) { request in
                                            // --- *** THIS IS THE FIX *** ---
                                            NavigationLink(destination: InstructorPublicProfileView(instructorID: request.instructorID)) {
                                                MyInstructorRow(request: request)
                                            }
                                            // --- *** END OF FIX *** ---
                                        }
                                    }
                                }
                                
                                // --- Section for Denied ---
                                if !deniedRequests.isEmpty {
                                    Section("Denied Requests") {
                                        ForEach(deniedRequests) { request in
                                            // --- *** THIS IS THE FIX *** ---
                                            NavigationLink(destination: InstructorPublicProfileView(instructorID: request.instructorID)) {
                                                MyInstructorRow(request: request)
                                            }
                                            // --- *** END OF FIX *** ---
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
            // This fetch is still correct, it gets all requests
            self.sentRequests = try await communityManager.fetchSentRequests(for: studentID)
        } catch {
            print("Failed to fetch sent requests: \(error)")
        }
        isLoading = false
    }
}

// This helper view loads the instructor's details
struct MyInstructorRow: View {
    @EnvironmentObject var dataService: DataService
    let request: StudentRequest
    
    // --- REMOVED: onCancel callback ---
    
    @State private var instructor: AppUser?
    
    var body: some View {
        // --- REMOVED: The VStack wrapper ---
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
        // --- REMOVED: The visible "Cancel Request" button ---
    }
}
