// File: arafatrahman/myinstructor/MyInstructor-main/MyInstructor/Features/Lessons/StudentTrackExamView.swift
// --- UPDATED: Fixed 'Missing argument for parameter status' error ---

import SwiftUI

struct StudentTrackExamView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var lessonManager: LessonManager
    @EnvironmentObject var authManager: AuthManager
    
    var onSave: () -> Void
    
    // Form State
    @State private var date = Date()
    @State private var testCenter = ""
    @State private var isPass = false
    @State private var minorFaults = 0
    @State private var seriousFaults = 0
    @State private var notes = ""
    
    @State private var isLoading = false
    @State private var errorMessage: String?
    
    var isFormValid: Bool {
        !testCenter.isEmpty
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section("Exam Details") {
                    DatePicker("Date & Time", selection: $date, displayedComponents: [.date, .hourAndMinute])
                    
                    TextField("Test Center", text: $testCenter)
                        .textContentType(.location)
                }
                
                Section("Result") {
                    Toggle("Passed", isOn: $isPass)
                        .tint(.accentGreen)
                    
                    Stepper(value: $minorFaults, in: 0...50) {
                        HStack {
                            Text("Minor Faults")
                            Spacer()
                            Text("\(minorFaults)")
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    Stepper(value: $seriousFaults, in: 0...10) {
                        HStack {
                            Text("Serious/Dangerous Faults")
                            Spacer()
                            Text("\(seriousFaults)")
                                .foregroundColor(.secondary)
                        }
                    }
                }
                
                Section("Notes (Optional)") {
                    TextField("Examiner feedback or comments...", text: $notes)
                }
                
                if let error = errorMessage {
                    Section {
                        Text(error).foregroundColor(.warningRed).font(.caption)
                    }
                }
            }
            .navigationTitle("Track Exam")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveExam()
                    }
                    .bold()
                    .disabled(!isFormValid || isLoading)
                }
            }
        }
    }
    
    private func saveExam() {
        guard let studentID = authManager.user?.id else { return }
        isLoading = true
        
        // Attempt to link the first instructor if available
        let instructorID = authManager.user?.instructorIDs?.first
        
        let exam = ExamResult(
            studentID: studentID,
            instructorID: instructorID, // Added optional instructorID
            date: date,
            testCenter: testCenter,
            status: .completed, // FIX: Added required status
            isPass: isPass,
            minorFaults: minorFaults,
            seriousFaults: seriousFaults,
            notes: notes.isEmpty ? nil : notes
        )
        
        Task {
            do {
                try await lessonManager.logExamResult(exam)
                onSave()
                dismiss()
            } catch {
                errorMessage = "Failed to save exam: \(error.localizedDescription)"
            }
            isLoading = false
        }
    }
}
