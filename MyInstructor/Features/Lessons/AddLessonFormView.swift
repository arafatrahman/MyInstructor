// File: arafatrahman/myinstructor/MyInstructor-main/MyInstructor/Features/Lessons/AddLessonFormView.swift
// --- This is the file from the previous step, for reference ---

import SwiftUI

struct SelectableStudent: Identifiable, Hashable {
    let id: String
    let name: String
    let address: String?
    let isOffline: Bool
    
    init(student: Student) {
        self.id = student.id ?? student.userID
        self.name = student.name
        self.address = student.address
        self.isOffline = false
    }
    
    init(offlineStudent: OfflineStudent) {
        self.id = offlineStudent.id ?? ""
        self.name = offlineStudent.name
        self.address = offlineStudent.address
        self.isOffline = true
    }
}

struct AddLessonFormView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var lessonManager: LessonManager
    @EnvironmentObject var dataService: DataService
    @EnvironmentObject var authManager: AuthManager
    
    var lessonToEdit: Lesson?
    var onLessonAdded: (Lesson) -> Void // Now returns the lesson
    
    // Topic State
    @State private var selectedTopics: [String] = []
    @State private var customTopic: String = ""
    private let predefinedTopics = [
        "Junctions", "Parking", "Roundabouts", "Clutch Control", "Speed Control", "Manoeuvres"
    ]
    
    // Student State
    @State private var allStudents: [SelectableStudent] = []
    @State private var selectedStudent: SelectableStudent? = nil

    // Lesson Details State
    @State private var startTime: Date = Date().addingTimeInterval(3600)
    @State private var durationHours: Double = 1.0
    @State private var pickupLocation: String = ""
    @State private var fee: String = "45.00"
    
    @State private var isLoading = false
    @State private var errorMessage: String?
    
    @State private var isEditing: Bool = false
    
    private var durationSeconds: TimeInterval {
        durationHours * 3600
    }
    
    private var finalTopicString: String {
        selectedTopics.joined(separator: ", ")
    }

    var body: some View {
        NavigationView {
            Form {
                // MARK: - Topic Section
                Section("Topics") {
                    if selectedTopics.isEmpty {
                        Text("Select one or more topics below.")
                            .foregroundColor(.textLight)
                    } else {
                        FlowLayout(alignment: .leading, spacing: 8) {
                            ForEach(selectedTopics, id: \.self) { topic in
                                Text(topic)
                                    .font(.caption)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(Color.primaryBlue.opacity(0.1))
                                    .foregroundColor(.primaryBlue)
                                    .cornerRadius(8)
                                    .onTapGesture {
                                        withAnimation {
                                            selectedTopics.removeAll { $0 == topic }
                                        }
                                    }
                            }
                        }
                    }
                    
                    ForEach(predefinedTopics, id: \.self) { topic in
                        Button(action: { toggleTopic(topic) }) {
                            HStack {
                                Text(topic)
                                Spacer()
                                if selectedTopics.contains(topic) {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(.accentGreen)
                                } else {
                                    Image(systemName: "circle")
                                        .foregroundColor(.textLight)
                                }
                            }
                        }
                        .buttonStyle(.plain)
                    }
                    
                    HStack {
                        TextField("Add custom topic...", text: $customTopic)
                        Button(action: addCustomTopic) {
                            Image(systemName: "plus.circle.fill")
                        }
                        .disabled(customTopic.isEmpty)
                    }
                }
                
                // MARK: - Student & Location
                Section("Student & Location") {
                    Picker("Student", selection: $selectedStudent) {
                        Text("Select Student").tag(nil as SelectableStudent?)
                        
                        Section("Online Students") {
                            ForEach(allStudents.filter { !$0.isOffline }) { student in
                                Text(student.name).tag(student as SelectableStudent?)
                            }
                        }
                        Section("Offline Students") {
                            ForEach(allStudents.filter { $0.isOffline }) { student in
                                Text(student.name).tag(student as SelectableStudent?)
                            }
                        }
                    }
                    .disabled(isEditing)
                    
                    TextField("Pickup Location", text: $pickupLocation)
                        .textContentType(.fullStreetAddress)
                }
                .onChange(of: selectedStudent) { _, newStudent in
                    if !isEditing {
                        if let student = newStudent, let address = student.address, !address.isEmpty {
                            self.pickupLocation = address
                        } else {
                            self.pickupLocation = ""
                        }
                    }
                }
                
                // MARK: - Lesson Details
                Section("Lesson Details") {
                    DatePicker("Date & Time", selection: $startTime, displayedComponents: [.date, .hourAndMinute])
                        .datePickerStyle(.compact)
                    
                    VStack(alignment: .leading) {
                        Text("Duration: \(durationHours, specifier: "%.1f") hours")
                            .font(.subheadline).bold()
                        Slider(value: $durationHours, in: 0.5...3.0, step: 0.5)
                            .tint(.primaryBlue)
                    }
                    
                    HStack {
                        Text("Fee (£)")
                        Spacer()
                        TextField("Amount", text: $fee)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                    }
                }
                
                if let error = errorMessage {
                    Section {
                        Text(error).foregroundColor(.warningRed)
                    }
                }
            }
            .navigationTitle(isEditing ? "Edit Lesson" : "Add New Lesson")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        saveLessonAction()
                    } label: {
                        if isLoading {
                            ProgressView()
                        } else {
                            Text(isEditing ? "Save" : "Schedule")
                                .bold()
                        }
                    }
                    .disabled(!isFormValid || isLoading)
                }
            }
            .task {
                await fetchAllStudents()
                
                if let lesson = lessonToEdit {
                    self.isEditing = true
                    
                    self.selectedTopics = lesson.topic.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
                    
                    self.startTime = lesson.startTime
                    self.durationHours = (lesson.duration ?? 3600) / 3600
                    self.pickupLocation = lesson.pickupLocation
                    self.fee = String(format: "%.2f", lesson.fee)
                    
                    self.selectedStudent = allStudents.first(where: { $0.id == lesson.studentID })
                }
            }
        }
    }
    
    // --- *** HELPER FUNCTIONS *** ---
    
    private func toggleTopic(_ topic: String) {
        withAnimation {
            if let index = selectedTopics.firstIndex(of: topic) {
                selectedTopics.remove(at: index)
            } else {
                selectedTopics.append(topic)
            }
        }
    }
    
    private func addCustomTopic() {
        let trimmedTopic = customTopic.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedTopic.isEmpty && !selectedTopics.contains(trimmedTopic) {
            withAnimation {
                selectedTopics.append(trimmedTopic)
                customTopic = ""
            }
        }
    }
    
    private var isFormValid: Bool {
        !selectedTopics.isEmpty && selectedStudent != nil && !pickupLocation.isEmpty && (Double(fee) ?? 0 > 0)
    }
    
    private func fetchAllStudents() async {
        guard let instructorID = authManager.user?.id else {
            errorMessage = "Could not find instructor ID."
            return
        }
        
        do {
            async let onlineStudents = dataService.fetchStudents(for: instructorID)
            async let offlineStudents = dataService.fetchOfflineStudents(for: instructorID)
            
            let online = try await onlineStudents
            let offline = try await offlineStudents
            
            let selectableOnline = online.map { SelectableStudent(student: $0) }
            let selectableOffline = offline.map { SelectableStudent(offlineStudent: $0) }
            
            self.allStudents = (selectableOnline + selectableOffline).sorted(by: { $0.name < $1.name })
            
        } catch {
            errorMessage = "Failed to load students: \(error.localizedDescription)"
        }
    }
    
    private func saveLessonAction() {
        guard let student = selectedStudent, let instructorID = authManager.user?.id else {
            errorMessage = "Instructor ID or Student not selected."
            return
        }
        
        isLoading = true
        errorMessage = nil
        
        var lessonToSave = Lesson(
            id: lessonToEdit?.id,
            instructorID: instructorID,
            studentID: student.id,
            topic: finalTopicString,
            startTime: startTime,
            duration: durationSeconds,
            pickupLocation: pickupLocation,
            fee: Double(fee) ?? 0.0,
            notes: lessonToEdit?.notes,
            status: lessonToEdit?.status ?? .scheduled
        )
        
        Task {
            do {
                if isEditing {
                    try await lessonManager.updateLesson(lessonToSave)
                } else {
                    try await lessonManager.addLesson(newLesson: lessonToSave)
                }
                
                onLessonAdded(lessonToSave) // Pass the saved lesson back
                dismiss()
                
            } catch {
                errorMessage = "Failed to save lesson: \(error.localizedDescription)"
            }
            isLoading = false
        }
    }
}
