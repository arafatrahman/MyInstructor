// File: arafatrahman/myinstructor/MyInstructor-main/MyInstructor/Features/Lessons/StudentLogPracticeView.swift
// --- UPDATED: Topic selection is now optional ---

import SwiftUI

struct StudentLogPracticeView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var lessonManager: LessonManager
    @EnvironmentObject var authManager: AuthManager
    
    var onSave: () -> Void
    
    @State private var date = Date()
    @State private var durationString = "1.0"
    @State private var practiceType = "Private Practice"
    @State private var selectedTopic: String = "" // Default to empty (None)
    @State private var notes = ""
    
    @State private var isLoading = false
    @State private var errorMessage: String?
    
    let practiceTypes = ["Private Practice", "Lesson with Friend/Family", "Official Lesson"]
    
    var body: some View {
        NavigationView {
            Form {
                Section("Session Details") {
                    DatePicker("Date", selection: $date, displayedComponents: [.date, .hourAndMinute])
                    
                    HStack {
                        Text("Duration (Hours)")
                        Spacer()
                        TextField("e.g. 1.5", text: $durationString)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                    }
                    
                    Picker("Type", selection: $practiceType) {
                        ForEach(practiceTypes, id: \.self) { type in
                            Text(type).tag(type)
                        }
                    }
                }
                
                // --- TOPIC SELECTION (Optional) ---
                Section("Focus Topic (Optional)") {
                    Picker("Select Topic", selection: $selectedTopic) {
                        Text("None").tag("") // Option to leave blank
                        
                        ForEach(DrivingTopics.all, id: \.self) { topic in
                            Text(topic).tag(topic)
                        }
                    }
                    .pickerStyle(.navigationLink)
                }
                
                Section("Notes") {
                    TextField("What went well? What needs work?", text: $notes)
                }
                
                if let error = errorMessage {
                    Text(error).foregroundColor(.red).font(.caption)
                }
            }
            .navigationTitle("Log Practice")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { saveSession() }
                        .bold()
                        .disabled(durationString.isEmpty || isLoading)
                }
            }
        }
    }
    
    private func saveSession() {
        guard let studentID = authManager.user?.id else { return }
        guard let hours = Double(durationString), hours > 0 else {
            errorMessage = "Invalid duration"
            return
        }
        
        isLoading = true
        
        let session = PracticeSession(
            studentID: studentID,
            date: date,
            duration: hours * 3600, // Convert to seconds
            practiceType: practiceType,
            topic: selectedTopic.isEmpty ? nil : selectedTopic, // Save as nil if empty
            notes: notes.isEmpty ? nil : notes
        )
        
        Task {
            do {
                try await lessonManager.logPracticeSession(session)
                onSave()
                dismiss()
            } catch {
                errorMessage = "Failed to save: \(error.localizedDescription)"
            }
            isLoading = false
        }
    }
}
