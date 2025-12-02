// File: arafatrahman/myinstructor/MyInstructor-main/MyInstructor/Features/Common/AddNoteView.swift
// --- UPDATED: Separated Title and Content Logic ---

import SwiftUI

struct AddNoteView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var lessonManager: LessonManager
    @EnvironmentObject var authManager: AuthManager
    
    // Optional: Pass this in to switch to "Edit Mode"
    var noteToEdit: PracticeSession?
    
    var onSave: () -> Void
    
    @State private var date = Date()
    @State private var noteTitle = ""
    @State private var noteContent = ""
    @State private var isLoading = false
    @State private var errorMessage: String?
    
    var isEditing: Bool { noteToEdit != nil }
    
    var isFormValid: Bool {
        !noteContent.isEmpty
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section("Note Details") {
                    DatePicker("Date", selection: $date, displayedComponents: [.date, .hourAndMinute])
                    TextField("Title (Optional)", text: $noteTitle)
                }
                
                Section("Content") {
                    TextEditor(text: $noteContent)
                        .frame(height: 150)
                        .overlay(alignment: .topLeading) {
                            if noteContent.isEmpty {
                                Text("Write your note here...")
                                    .foregroundColor(Color(.placeholderText))
                                    .padding(.top, 8)
                                    .padding(.leading, 5)
                            }
                        }
                }
                
                if let error = errorMessage {
                    Text(error).foregroundColor(.red).font(.caption)
                }
            }
            .navigationTitle(isEditing ? "Edit Note" : "Add Note")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { saveNote() }
                        .bold()
                        .disabled(!isFormValid || isLoading)
                }
            }
            .onAppear {
                // Populate fields if editing
                if let note = noteToEdit {
                    date = note.date
                    // Load title and content separately
                    noteTitle = note.title ?? ""
                    noteContent = note.notes ?? ""
                }
            }
        }
    }
    
    private func saveNote() {
        guard let userID = authManager.user?.id else { return }
        isLoading = true
        
        let session = PracticeSession(
            id: noteToEdit?.id,
            studentID: userID,
            date: date,
            duration: 0,
            practiceType: "Personal Note",
            topic: nil,
            // Save fields separately
            title: noteTitle.isEmpty ? nil : noteTitle,
            notes: noteContent.isEmpty ? nil : noteContent
        )
        
        Task {
            do {
                if isEditing {
                    try await lessonManager.updatePracticeSession(session)
                } else {
                    try await lessonManager.logPracticeSession(session)
                }
                onSave()
                dismiss()
            } catch {
                errorMessage = "Failed to save: \(error.localizedDescription)"
            }
            isLoading = false
        }
    }
}
