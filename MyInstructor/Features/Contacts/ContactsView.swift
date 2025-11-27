// File: arafatrahman/myinstructor/MyInstructor-main/MyInstructor/Features/Contacts/ContactsView.swift
// --- UPDATED: Added safety check to callNumber to prevent Simulator errors ---

import SwiftUI

struct ContactsView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var contactManager: ContactManager
    @EnvironmentObject var dataService: DataService
    @EnvironmentObject var authManager: AuthManager
    @EnvironmentObject var communityManager: CommunityManager // For deleting students
    
    @State private var contacts: [DisplayContact] = []
    @State private var searchText = ""
    @State private var isLoading = true
    
    // Sheets & Alerts
    @State private var isAddContactSheetPresented = false
    @State private var contactToEdit: CustomContact? = nil
    @State private var studentToEdit: OfflineStudent? = nil
    
    @State private var itemToDelete: DisplayContact? = nil
    @State private var isShowingDeleteAlert = false
    
    // Alert for Simulator/No Phone capability
    @State private var isShowingCallErrorAlert = false
    
    var filteredContacts: [DisplayContact] {
        if searchText.isEmpty {
            return contacts
        }
        return contacts.filter {
            $0.name.localizedCaseInsensitiveContains(searchText) ||
            $0.phone.localizedCaseInsensitiveContains(searchText)
        }
    }
    
    var body: some View {
        NavigationView {
            VStack {
                // Search Bar
                SearchBar(text: $searchText, placeholder: "Search contacts...")
                    .padding(.horizontal)
                    .padding(.top, 10)
                
                if isLoading {
                    Spacer()
                    ProgressView("Loading Contacts...")
                    Spacer()
                } else if contacts.isEmpty {
                    Spacer()
                    EmptyStateView(
                        icon: "person.crop.circle.badge.plus",
                        message: "No contacts found.",
                        actionTitle: "Add Contact",
                        action: { isAddContactSheetPresented = true }
                    )
                    Spacer()
                } else {
                    List {
                        ForEach(filteredContacts) { contact in
                            ContactListRow(contact: contact, onCall: {
                                callNumber(contact.phone)
                            })
                            .swipeActions(edge: .trailing) {
                                // Delete Action
                                Button(role: .destructive) {
                                    itemToDelete = contact
                                    isShowingDeleteAlert = true
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                                
                                // Edit Action
                                Button {
                                    handleEdit(contact)
                                } label: {
                                    Label("Edit", systemImage: "pencil")
                                }
                                .tint(.primaryBlue)
                            }
                        }
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("Quick Contacts")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: { dismiss() }) {
                        HStack(spacing: 5) {
                            Image(systemName: "chevron.left")
                            Text("Back")
                        }
                        .foregroundColor(.textDark)
                    }
                }
                
                ToolbarItem(placement: .primaryAction) {
                    Button { isAddContactSheetPresented = true } label: {
                        Image(systemName: "plus")
                            .font(.headline.bold())
                    }
                }
            }
            // Sheets
            .sheet(isPresented: $isAddContactSheetPresented) {
                AddContactFormView(onSave: { Task { await fetchData() } })
            }
            .sheet(item: $contactToEdit) { contact in
                AddContactFormView(contactToEdit: contact, onSave: {
                    contactToEdit = nil
                    Task { await fetchData() }
                })
            }
            .sheet(item: $studentToEdit) { offlineStudent in
                OfflineStudentFormView(studentToEdit: offlineStudent, onStudentAdded: {
                    studentToEdit = nil
                    Task { await fetchData() }
                })
            }
            // Delete Alert
            .alert("Delete Contact?", isPresented: $isShowingDeleteAlert, presenting: itemToDelete) { item in
                Button("Cancel", role: .cancel) {}
                Button("Delete", role: .destructive) {
                    Task { await deleteItem(item) }
                }
            } message: { item in
                if case .student(let s) = item.type, !s.isOffline {
                    Text("Warning: You are about to remove an active Online Student. This will disconnect them from your account.")
                } else {
                    Text("Are you sure you want to delete \(item.name)?")
                }
            }
            // Call Error Alert (For Simulator)
            .alert("Cannot Make Call", isPresented: $isShowingCallErrorAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                Text("Your device does not support phone calls, or is a Simulator.")
            }
            .task { await fetchData() }
        }
    }
    
    // MARK: - Logic
    
    func fetchData() async {
        guard let id = authManager.user?.id else { return }
        isLoading = true
        
        async let studentsTask = fetchStudentsSafe(for: id)
        async let customContactsTask = fetchCustomContactsSafe(for: id)
        
        let studentContacts = await studentsTask
        let customContacts = await customContactsTask
        
        // Merge & Sort
        self.contacts = (studentContacts + customContacts).sorted { $0.name < $1.name }
        
        isLoading = false
    }
    
    private func fetchStudentsSafe(for id: String) async -> [DisplayContact] {
        do {
            let students = try await dataService.fetchAllStudents(for: id)
            return students.compactMap { student -> DisplayContact? in
                guard let phone = student.phone, !phone.isEmpty else { return nil }
                return DisplayContact(
                    id: student.id ?? UUID().uuidString,
                    name: student.name,
                    phone: phone,
                    photoURL: student.photoURL,
                    type: .student(student)
                )
            }
        } catch {
            print("Error fetching students: \(error.localizedDescription)")
            return []
        }
    }
    
    private func fetchCustomContactsSafe(for id: String) async -> [DisplayContact] {
        do {
            let custom = try await contactManager.fetchCustomContacts(for: id)
            return custom.map { c in
                DisplayContact(
                    id: c.id ?? UUID().uuidString,
                    name: c.name,
                    phone: c.phone,
                    photoURL: nil,
                    type: .custom(c)
                )
            }
        } catch {
            print("Error fetching custom contacts: \(error.localizedDescription)")
            return []
        }
    }
    
    // --- UPDATED CALL FUNCTION ---
    func callNumber(_ number: String) {
        let cleanNumber = number.filter("0123456789+".contains)
        guard let url = URL(string: "tel://\(cleanNumber)") else { return }
        
        if UIApplication.shared.canOpenURL(url) {
            UIApplication.shared.open(url)
        } else {
            // If we can't open the URL (e.g. Simulator), show an alert or log it
            print("Device cannot make calls (Simulator detected).")
            isShowingCallErrorAlert = true
        }
    }
    
    func handleEdit(_ item: DisplayContact) {
        switch item.type {
        case .custom(let c):
            self.contactToEdit = c
        case .student(let s):
            if s.isOffline {
                self.studentToEdit = OfflineStudent(
                    id: s.id,
                    instructorID: authManager.user?.id ?? "",
                    name: s.name,
                    phone: s.phone,
                    email: s.email,
                    address: s.address
                )
            } else {
                print("Cannot edit online student profile directly")
            }
        }
    }
    
    func deleteItem(_ item: DisplayContact) async {
        guard let instructorID = authManager.user?.id else { return }
        
        do {
            switch item.type {
            case .custom(let c):
                if let cid = c.id {
                    try await contactManager.deleteContact(contactID: cid, instructorID: instructorID)
                }
            case .student(let s):
                if let sid = s.id {
                    if s.isOffline {
                        try await communityManager.deleteOfflineStudent(studentID: sid)
                    } else {
                        try await communityManager.removeStudent(studentID: sid, instructorID: instructorID)
                    }
                }
            }
            await fetchData()
        } catch {
            print("Delete failed: \(error)")
        }
    }
}

// MARK: - Models & Subviews

struct DisplayContact: Identifiable {
    let id: String
    let name: String
    let phone: String
    let photoURL: String?
    let type: ContactSourceType
    
    enum ContactSourceType {
        case student(Student)
        case custom(CustomContact)
    }
}

struct ContactListRow: View {
    let contact: DisplayContact
    let onCall: () -> Void
    
    var body: some View {
        HStack(spacing: 15) {
            // Avatar
            if let urlString = contact.photoURL, let url = URL(string: urlString) {
                AsyncImage(url: url) { phase in
                    if let image = phase.image {
                        image.resizable().scaledToFill()
                    } else {
                        Color.gray.opacity(0.3)
                    }
                }
                .frame(width: 50, height: 50)
                .clipShape(Circle())
            } else {
                ZStack {
                    Circle().fill(Color.primaryBlue.opacity(0.1))
                    Text(contact.name.prefix(1).uppercased())
                        .font(.title3).bold()
                        .foregroundColor(.primaryBlue)
                }
                .frame(width: 50, height: 50)
            }
            
            // Info
            VStack(alignment: .leading, spacing: 4) {
                Text(contact.name)
                    .font(.headline)
                    .foregroundColor(.primary)
                
                HStack {
                    Image(systemName: "phone.fill")
                        .font(.caption2)
                    Text(contact.phone)
                        .font(.subheadline)
                }
                .foregroundColor(.secondary)
            }
            
            Spacer()
            
            // Call Button
            Button(action: onCall) {
                Image(systemName: "phone.circle.fill")
                    .font(.system(size: 32))
                    .foregroundColor(.accentGreen)
                    .shadow(color: .accentGreen.opacity(0.3), radius: 5)
            }
            .buttonStyle(.plain) // Important for List
        }
        .padding(.vertical, 5)
    }
}
