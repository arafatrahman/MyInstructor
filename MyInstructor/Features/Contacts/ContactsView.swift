// File: arafatrahman/myinstructor/MyInstructor-main/MyInstructor/Features/Contacts/ContactsView.swift
// --- UPDATED: Now supports Student view (fetches Instructors) ---

import SwiftUI

struct ContactsView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var contactManager: ContactManager
    @EnvironmentObject var dataService: DataService
    @EnvironmentObject var authManager: AuthManager
    @EnvironmentObject var communityManager: CommunityManager
    
    @State private var contacts: [DisplayContact] = []
    @State private var searchText = ""
    @State private var isLoading = true
    
    // Sheets & Alerts
    @State private var isAddContactSheetPresented = false
    @State private var contactToEdit: CustomContact? = nil
    @State private var studentToEdit: OfflineStudent? = nil
    
    @State private var itemToDelete: DisplayContact? = nil
    @State private var isShowingDeleteAlert = false
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
                                Button(role: .destructive) {
                                    itemToDelete = contact
                                    isShowingDeleteAlert = true
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                                
                                // Only allow editing custom contacts or offline students
                                if case .custom = contact.type {
                                    Button { handleEdit(contact) } label: { Label("Edit", systemImage: "pencil") }
                                        .tint(.primaryBlue)
                                } else if case .student(let s) = contact.type, s.isOffline {
                                    Button { handleEdit(contact) } label: { Label("Edit", systemImage: "pencil") }
                                        .tint(.primaryBlue)
                                }
                            }
                        }
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("Contacts")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: { dismiss() }) {
                        HStack(spacing: 5) {
                            Image(systemName: "chevron.left")
                            Text("Back")
                        }
                    }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button { isAddContactSheetPresented = true } label: {
                        Image(systemName: "plus").font(.headline.bold())
                    }
                }
            }
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
            .alert("Delete Contact?", isPresented: $isShowingDeleteAlert, presenting: itemToDelete) { item in
                Button("Cancel", role: .cancel) {}
                Button("Delete", role: .destructive) {
                    Task { await deleteItem(item) }
                }
            } message: { item in
                if case .student(let s) = item.type, !s.isOffline {
                    Text("Remove \(s.name) from your students list?")
                } else if case .instructor(let u) = item.type {
                    Text("Remove instructor \(u.name ?? "User") from your list?")
                } else {
                    Text("Are you sure you want to delete \(item.name)?")
                }
            }
            .alert("Cannot Make Call", isPresented: $isShowingCallErrorAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                Text("Your device cannot make calls.")
            }
            .task { await fetchData() }
        }
    }
    
    // MARK: - Logic
    
    func fetchData() async {
        guard let id = authManager.user?.id else { return }
        isLoading = true
        
        // 1. Fetch Custom Contacts (Everyone has these)
        async let customContactsTask = fetchCustomContactsSafe(for: id)
        
        var mergedContacts: [DisplayContact] = []
        
        // 2. Fetch Role-Specific Contacts
        if authManager.role == .student {
            async let instructorsTask = fetchInstructorsSafe(for: id)
            let (custom, instructors) = await (customContactsTask, instructorsTask)
            mergedContacts = custom + instructors
        } else {
            async let studentsTask = fetchStudentsSafe(for: id)
            let (custom, students) = await (customContactsTask, studentsTask)
            mergedContacts = custom + students
        }
        
        self.contacts = mergedContacts.sorted { $0.name < $1.name }
        isLoading = false
    }
    
    // Fetch Students (For Instructor)
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
        } catch { return [] }
    }
    
    // Fetch Instructors (For Student) - NEW
    private func fetchInstructorsSafe(for id: String) async -> [DisplayContact] {
        let instructorIDs = authManager.user?.instructorIDs ?? []
        var results: [DisplayContact] = []
        
        for instID in instructorIDs {
            if let user = try? await dataService.fetchUser(withId: instID), let phone = user.phone, !phone.isEmpty {
                results.append(DisplayContact(
                    id: user.id ?? UUID().uuidString,
                    name: user.name ?? "Instructor",
                    phone: phone,
                    photoURL: user.photoURL,
                    type: .instructor(user)
                ))
            }
        }
        return results
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
        } catch { return [] }
    }
    
    func callNumber(_ number: String) {
        let cleanNumber = number.filter("0123456789+".contains)
        guard let url = URL(string: "tel://\(cleanNumber)") else { return }
        if UIApplication.shared.canOpenURL(url) {
            UIApplication.shared.open(url)
        } else {
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
            }
        default: break // Online students/instructors cannot be edited here
        }
    }
    
    func deleteItem(_ item: DisplayContact) async {
        guard let currentUserID = authManager.user?.id else { return }
        
        do {
            switch item.type {
            case .custom(let c):
                if let cid = c.id { try await contactManager.deleteContact(contactID: cid, instructorID: currentUserID) }
            case .student(let s):
                if let sid = s.id {
                    if s.isOffline { try await communityManager.deleteOfflineStudent(studentID: sid) }
                    else { try await communityManager.removeStudent(studentID: sid, instructorID: currentUserID) }
                }
            case .instructor(let u):
                if let iid = u.id {
                    try await communityManager.removeInstructor(instructorID: iid, studentID: currentUserID)
                }
            }
            await fetchData()
        } catch { print("Delete failed: \(error)") }
    }
}

// Updated Models
struct DisplayContact: Identifiable {
    let id: String
    let name: String
    let phone: String
    let photoURL: String?
    let type: ContactSourceType
    
    enum ContactSourceType {
        case student(Student)
        case instructor(AppUser) // <--- Added Instructor Case
        case custom(CustomContact)
    }
}

// Reuse ContactListRow from previous code (unchanged visual)
struct ContactListRow: View {
    let contact: DisplayContact
    let onCall: () -> Void
    var body: some View {
        HStack(spacing: 15) {
            if let urlString = contact.photoURL, let url = URL(string: urlString) {
                AsyncImage(url: url) { phase in
                    if let image = phase.image { image.resizable().scaledToFill() } else { Color.gray.opacity(0.3) }
                }.frame(width: 50, height: 50).clipShape(Circle())
            } else {
                ZStack {
                    Circle().fill(Color.primaryBlue.opacity(0.1))
                    Text(contact.name.prefix(1).uppercased()).font(.title3).bold().foregroundColor(.primaryBlue)
                }.frame(width: 50, height: 50)
            }
            VStack(alignment: .leading, spacing: 4) {
                Text(contact.name).font(.headline).foregroundColor(.primary)
                HStack { Image(systemName: "phone.fill").font(.caption2); Text(contact.phone).font(.subheadline) }.foregroundColor(.secondary)
            }
            Spacer()
            Button(action: onCall) {
                Image(systemName: "phone.circle.fill").font(.system(size: 32)).foregroundColor(.accentGreen)
            }.buttonStyle(.plain)
        }.padding(.vertical, 5)
    }
}
