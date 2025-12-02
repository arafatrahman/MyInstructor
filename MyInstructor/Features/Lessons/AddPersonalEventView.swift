// File: MyInstructor/Features/Lessons/AddPersonalEventView.swift
import SwiftUI

struct AddPersonalEventView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var personalEventManager: PersonalEventManager
    @EnvironmentObject var authManager: AuthManager
    
    var eventToEdit: PersonalEvent?
    var onSave: () -> Void
    
    @State private var title: String = ""
    @State private var date: Date = Date()
    @State private var durationHours: Double = 1.0 // Default 1 hour
    @State private var notes: String = ""
    
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var isShowingDeleteAlert = false
    
    var isEditing: Bool { eventToEdit != nil }
    var isFormValid: Bool { !title.isEmpty }
    
    var body: some View {
        NavigationView {
            Form {
                Section("Event Details") {
                    TextField("Title (e.g. Dentist, Gym)", text: $title)
                    
                    DatePicker("Date & Time", selection: $date, displayedComponents: [.date, .hourAndMinute])
                }
                
                Section("Notes") {
                    TextField("Add details...", text: $notes)
                }
                
                if let error = errorMessage {
                    Section {
                        Text(error).foregroundColor(.red).font(.caption)
                    }
                }
                
                // --- Delete Button (Only when editing) ---
                if isEditing {
                    Section {
                        Button(role: .destructive) {
                            isShowingDeleteAlert = true
                        } label: {
                            HStack {
                                Spacer()
                                Text("Delete Event")
                                Spacer()
                            }
                        }
                    }
                }
            }
            .navigationTitle(isEditing ? "Edit Event" : "Add Personal Event")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { saveEvent() }
                        .bold()
                        .disabled(!isFormValid || isLoading)
                }
            }
            .onAppear {
                if let event = eventToEdit {
                    title = event.title
                    date = event.date
                    durationHours = event.duration / 3600.0
                    notes = event.notes ?? ""
                } else {
                    let nextHour = Calendar.current.date(byAdding: .hour, value: 1, to: Date()) ?? Date()
                    date = nextHour
                }
            }
            .alert("Delete Event?", isPresented: $isShowingDeleteAlert) {
                Button("Cancel", role: .cancel) { }
                Button("Delete", role: .destructive) {
                    deleteEvent()
                }
            } message: {
                Text("Are you sure you want to delete this event?")
            }
        }
    }
    
    private func saveEvent() {
        guard let userID = authManager.user?.id else { return }
        isLoading = true
        
        let event = PersonalEvent(
            id: eventToEdit?.id,
            userID: userID,
            title: title,
            date: date,
            duration: 3600, // Default to 1 hour fixed
            notes: notes.isEmpty ? nil : notes
        )
        
        Task {
            do {
                if isEditing {
                    try await personalEventManager.updateEvent(event)
                } else {
                    try await personalEventManager.addEvent(event)
                }
                onSave()
                dismiss()
            } catch {
                errorMessage = "Failed to save: \(error.localizedDescription)"
            }
            isLoading = false
        }
    }
    
    private func deleteEvent() {
        guard let eventID = eventToEdit?.id else { return }
        isLoading = true
        Task {
            do {
                try await personalEventManager.deleteEvent(id: eventID)
                onSave() // Trigger refresh
                dismiss()
            } catch {
                errorMessage = "Failed to delete: \(error.localizedDescription)"
                isLoading = false
            }
        }
    }
}
