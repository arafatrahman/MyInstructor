// File: MyInstructor/Features/Student/StudentRequestsView.swift
// (This is a NEW file)

import SwiftUI

struct StudentRequestsView: View {
    @EnvironmentObject var authManager: AuthManager
    @EnvironmentObject var communityManager: CommunityManager
    
    @State private var sentRequests: [StudentRequest] = []
    @State private var isLoading = true
    
    // --- NEW ---
    @State private var selectedStatus: RequestStatusFilter = .approved
    
    // --- NEW COMPUTED PROPERTIES ---
    private var approvedRequests: [StudentRequest] {
        sentRequests.filter { $0.status == .approved }
    }
    
    private var otherRequests: [StudentRequest] {
        sentRequests.filter { $0.status == .pending || $0.status == .denied }
    }
    
    var body: some View {
        NavigationView {
            VStack {
                // --- NEW PICKER ---
                Picker("Request Status", selection: $selectedStatus) {
                    Text("Approved (\(approvedRequests.count))").tag(RequestStatusFilter.approved)
                    Text("Pending (\(otherRequests.count))").tag(RequestStatusFilter.pending)
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)
                
                if isLoading {
                    ProgressView("Loading Requests...")
                        .frame(maxHeight: .infinity)
                } else {
                    // --- UPDATED LOGIC ---
                    if selectedStatus == .approved {
                        if approvedRequests.isEmpty {
                            EmptyStateView(
                                icon: "person.badge.plus",
                                message: "You have no approved instructors yet.",
                                actionTitle: "Find an Instructor",
                                action: {
                                    // TODO: This should ideally switch to the Community tab
                                    print("Finding instructor...")
                                }
                            )
                        } else {
                            List {
                                Section("Approved Instructors") {
                                    ForEach(approvedRequests) { request in
                                        StudentRequestRow(request: request)
                                    }
                                }
                            }
                            .listStyle(.insetGrouped)
                        }
                    } else {
                        if otherRequests.isEmpty {
                            EmptyStateView(
                                icon: "paperplane.fill",
                                message: "You have no pending or denied requests."
                            )
                        } else {
                            List {
                                Section("Pending & Denied Requests") {
                                    ForEach(otherRequests) { request in
                                        StudentRequestRow(request: request)
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
        } catch {
            print("Failed to fetch sent requests: \(error)")
        }
        isLoading = false
    }
}

// --- NEW ENUM ---
enum RequestStatusFilter {
    case approved, pending
}


// This helper view loads the instructor's details
struct StudentRequestRow: View {
    // We need DataService to fetch the user
    @EnvironmentObject var dataService: DataService
    let request: StudentRequest
    
    @State private var instructor: AppUser?
    
    var body: some View {
        HStack(spacing: 12) {
            // Instructor Photo
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

            // Instructor Name
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
            
            // Status Badge
            StatusBadge(status: request.status)
        }
        .padding(.vertical, 6)
        .task {
            // Fetch the instructor's info only if we don't have it
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
    
    var text: String {
        switch status {
        case .pending: return "Pending"
        case .approved: return "Approved"
        case .denied: return "Denied"
        }
    }
    
    var color: Color {
        switch status {
        case .pending: return .orange
        case .approved: return .accentGreen
        case .denied: return .warningRed
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
