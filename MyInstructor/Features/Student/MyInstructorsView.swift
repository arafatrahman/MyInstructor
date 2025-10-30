// File: MyInstructor/Features/Student/MyInstructorsView.swift
// --- UPDATED to fix 'ambiguous' and 'redeclaration' errors ---

import SwiftUI

// This enum now has a unique name to avoid conflicts
enum MyInstructorsFilter {
    case approved, pending
}

struct MyInstructorsView: View {
    @EnvironmentObject var authManager: AuthManager
    @EnvironmentObject var communityManager: CommunityManager
    
    @State private var sentRequests: [StudentRequest] = []
    @State private var isLoading = true
    
    // Use the uniquely named enum
    @State private var selectedStatus: MyInstructorsFilter = .approved
    
    private var approvedRequests: [StudentRequest] {
        sentRequests.filter { $0.status == .approved }
    }
    
    private var otherRequests: [StudentRequest] {
        sentRequests.filter { $0.status == .pending || $0.status == .denied }
    }
    
    var body: some View {
        NavigationView {
            VStack {
                // Use the uniquely named enum in the picker
                Picker("Request Status", selection: $selectedStatus) {
                    Text("My Instructors (\(approvedRequests.count))").tag(MyInstructorsFilter.approved)
                    Text("Pending (\(otherRequests.count))").tag(MyInstructorsFilter.pending)
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)
                
                if isLoading {
                    ProgressView("Loading Requests...")
                        .frame(maxHeight: .infinity)
                } else {
                    // Check against the uniquely named enum
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
                                        MyInstructorRow(request: request)
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
                                        MyInstructorRow(request: request)
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

// This helper view loads the instructor's details
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
            
            // This will now use the 'StatusBadge'
            // struct defined in your other file
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
    }
}

// --- *** THE DUPLICATE StatusBadge STRUCT HAS BEEN REMOVED FROM HERE *** ---
