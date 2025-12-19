// File: arafatrahman/myinstructor/MyInstructor-main/MyInstructor/Features/Common/NotesListView.swift
// --- UPDATED: Displays Priority Color Indicator ---

import SwiftUI

struct NotesListView: View {
    @EnvironmentObject var lessonManager: LessonManager
    @EnvironmentObject var authManager: AuthManager
    @Environment(\.dismiss) var dismiss
    
    @State private var notes: [PracticeSession] = []
    @State private var isLoading = true
    
    // State for Sheets
    @State private var isAddingNote = false
    @State private var noteToEdit: PracticeSession? = nil
    
    var body: some View {
        NavigationView {
            VStack {
                if isLoading {
                    ProgressView("Loading Notes...")
                } else if notes.isEmpty {
                    EmptyStateView(
                        icon: "note.text",
                        message: "You haven't added any notes yet.",
                        actionTitle: "Add First Note",
                        action: { isAddingNote = true }
                    )
                } else {
                    List {
                        ForEach(notes) { note in
                            Button {
                                // Tap to Edit
                                noteToEdit = note
                            } label: {
                                HStack(alignment: .top, spacing: 12) {
                                    
                                    // --- ADDED: Priority Indicator ---
                                    if let priority = note.priority {
                                        RoundedRectangle(cornerRadius: 2)
                                            .fill(priorityColor(priority))
                                            .frame(width: 4)
                                            .padding(.vertical, 2)
                                    }
                                    
                                    VStack(alignment: .leading, spacing: 6) {
                                        // Display Title if available
                                        if let title = note.title, !title.isEmpty {
                                            Text(title)
                                                .font(.headline)
                                                .foregroundColor(.primary)
                                        }
                                        
                                        // Display Content
                                        Text(note.notes ?? "No Content")
                                            .font(.body)
                                            .foregroundColor(note.title?.isEmpty == false ? .secondary : .primary)
                                            .lineLimit(4)
                                        
                                        // Date Footer
                                        HStack {
                                            Text(note.date.formatted(date: .abbreviated, time: .shortened))
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                            Spacer()
                                            
                                            // Optional: Display Priority Text as well
                                            if let priority = note.priority {
                                                Text(priority.rawValue)
                                                    .font(.caption2)
                                                    .fontWeight(.bold)
                                                    .padding(.horizontal, 6)
                                                    .padding(.vertical, 2)
                                                    .background(priorityColor(priority).opacity(0.1))
                                                    .foregroundColor(priorityColor(priority))
                                                    .cornerRadius(4)
                                            }
                                        }
                                    }
                                }
                                .padding(.vertical, 4)
                            }
                            .buttonStyle(.plain) // Standard list behavior
                            .swipeActions(edge: .trailing) {
                                // Delete Action
                                Button(role: .destructive) {
                                    deleteNote(note)
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                                
                                // Edit Action
                                Button {
                                    noteToEdit = note
                                } label: {
                                    Label("Edit", systemImage: "pencil")
                                }
                                .tint(.orange)
                            }
                        }
                    }
                    .listStyle(.insetGrouped)
                }
            }
            .navigationTitle("My Notes")
            .navigationBarTitleDisplayMode(.inline)
            .background(Color(.systemGroupedBackground))
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") { dismiss() }
                }
                
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        isAddingNote = true
                    } label: {
                        Image(systemName: "plus")
                            .font(.headline)
                    }
                }
            }
            // Sheet for Adding
            .sheet(isPresented: $isAddingNote) {
                AddNoteView(onSave: {
                    Task { await fetchNotes() }
                })
            }
            // Sheet for Editing
            .sheet(item: $noteToEdit) { note in
                AddNoteView(noteToEdit: note, onSave: {
                    noteToEdit = nil
                    Task { await fetchNotes() }
                })
            }
            .task {
                await fetchNotes()
            }
        }
    }
    
    // MARK: - Logic
    
    private func fetchNotes() async {
        guard let userID = authManager.user?.id else { return }
        isLoading = true
        do {
            let allSessions = try await lessonManager.fetchPracticeSessions(for: userID)
            self.notes = allSessions.filter { $0.practiceType == "Personal Note" }
        } catch {
            print("Error fetching notes: \(error)")
        }
        isLoading = false
    }
    
    private func deleteNote(_ note: PracticeSession) {
        guard let id = note.id else { return }
        Task {
            try? await lessonManager.deletePracticeSession(id: id)
            await fetchNotes()
        }
    }
    
    // Helper for priority color
    private func priorityColor(_ p: NotePriority) -> Color {
        switch p {
        case .low: return .green
        case .medium: return .orange
        case .high: return .red
        }
    }
}
