// File: arafatrahman/myinstructor/MyInstructor-main/MyInstructor/Features/Vehicle/MileageLogView.swift
// --- UPDATED: Added Edit Capabilities ---

import SwiftUI

struct MileageLogView: View {
    @EnvironmentObject var vehicleManager: VehicleManager
    @EnvironmentObject var authManager: AuthManager
    @Environment(\.dismiss) var dismiss
    
    @State private var logs: [MileageLog] = []
    @State private var isLoading = true
    
    // Sheets
    @State private var isAddSheetPresented = false
    @State private var logToEdit: MileageLog? = nil
    
    var totalMiles: Int {
        logs.reduce(0) { $0 + $1.distance }
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Summary Card
                HStack {
                    VStack(alignment: .leading, spacing: 5) {
                        Text("Total Tracked")
                            .font(.subheadline)
                            .foregroundColor(.white.opacity(0.9))
                        Text("\(totalMiles) mi")
                            .font(.system(size: 28, weight: .bold))
                            .foregroundColor(.white)
                    }
                    Spacer()
                    Image(systemName: "speedometer")
                        .font(.system(size: 40))
                        .foregroundColor(.white.opacity(0.3))
                }
                .padding()
                .background(Color.cyan)
                .cornerRadius(16)
                .padding()
                .shadow(color: Color.cyan.opacity(0.3), radius: 8, x: 0, y: 4)
                
                // Logs List
                if isLoading {
                    Spacer()
                    ProgressView("Loading Logs...")
                    Spacer()
                } else if logs.isEmpty {
                    Spacer()
                    EmptyStateView(
                        icon: "road.lanes",
                        message: "No mileage logs yet.",
                        actionTitle: "Log First Trip",
                        action: { isAddSheetPresented = true }
                    )
                    Spacer()
                } else {
                    List {
                        ForEach(logs) { log in
                            Button {
                                logToEdit = log
                            } label: {
                                MileageLogRow(log: log)
                            }
                            .buttonStyle(.plain)
                            .listRowSeparator(.hidden)
                            .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
                            .swipeActions(edge: .trailing) {
                                Button(role: .destructive) {
                                    Task { await deleteLog(log.id!) }
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                        }
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("Mileage Log")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") { dismiss() }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button { isAddSheetPresented = true } label: {
                        Image(systemName: "plus").font(.headline.bold())
                    }
                }
            }
            // Add Sheet
            .sheet(isPresented: $isAddSheetPresented) {
                MileageLogFormView(onSave: { Task { await fetchData() } })
            }
            // Edit Sheet
            .sheet(item: $logToEdit) { log in
                MileageLogFormView(logToEdit: log, onSave: {
                    logToEdit = nil
                    Task { await fetchData() }
                })
            }
            .task { await fetchData() }
        }
    }
    
    private func fetchData() async {
        guard let id = authManager.user?.id else { return }
        isLoading = true
        do {
            logs = try await vehicleManager.fetchMileageLogs(for: id)
        } catch {
            print("Error fetching logs: \(error)")
        }
        isLoading = false
    }
    
    private func deleteLog(_ id: String) async {
        try? await vehicleManager.deleteMileageLog(id: id)
        withAnimation { logs.removeAll { $0.id == id } }
    }
}

struct MileageLogRow: View {
    let log: MileageLog
    
    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle().fill(Color.cyan.opacity(0.1)).frame(width: 45, height: 45)
                Image(systemName: "car.side.fill")
                    .foregroundColor(.cyan)
                    .font(.caption)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(log.purpose).font(.headline)
                Text(log.date.formatted(date: .abbreviated, time: .shortened))
                    .font(.caption).foregroundColor(.secondary)
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 4) {
                Text("\(log.distance) mi")
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Text("\(log.startReading) - \(log.endReading)")
                    .font(.caption2)
                    .padding(4)
                    .background(Color(.systemGray6))
                    .cornerRadius(4)
                    .foregroundColor(.secondary)
            }
        }
        .padding(12)
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.03), radius: 5, y: 2)
    }
}

// MARK: - Form View (Add & Edit)
struct MileageLogFormView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var vehicleManager: VehicleManager
    @EnvironmentObject var authManager: AuthManager
    
    var logToEdit: MileageLog?
    var onSave: () -> Void
    
    @State private var date = Date()
    @State private var selectedVehicleID = ""
    @State private var startReadingString = ""
    @State private var endReadingString = ""
    @State private var purpose = "Lesson"
    @State private var notes = ""
    
    @State private var availableVehicles: [Vehicle] = []
    @State private var isLoading = false
    @State private var isDataLoaded = false
    
    let purposes = ["Lesson", "Commute", "Personal", "Fuel Run", "Maintenance", "Other"]
    
    var isEditing: Bool { logToEdit != nil }
    
    var isValid: Bool {
        !selectedVehicleID.isEmpty &&
        !startReadingString.isEmpty &&
        !endReadingString.isEmpty &&
        (Int(endReadingString) ?? 0) >= (Int(startReadingString) ?? 0)
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section("Vehicle") {
                    if availableVehicles.isEmpty {
                        Text("No vehicles found").foregroundColor(.secondary)
                    } else {
                        Picker("Select Vehicle", selection: $selectedVehicleID) {
                            Text("Select Vehicle").tag("")
                            ForEach(availableVehicles) { v in
                                Text(v.displayName).tag(v.id ?? "")
                            }
                        }
                    }
                }
                
                Section("Trip Details") {
                    DatePicker("Date", selection: $date)
                    
                    Picker("Purpose", selection: $purpose) {
                        ForEach(purposes, id: \.self) { p in
                            Text(p).tag(p)
                        }
                    }
                    // Custom purpose input
                    if !purposes.contains(purpose) {
                        TextField("Custom Purpose", text: $purpose)
                    }
                    
                    HStack {
                        Text("Start Odometer")
                        Spacer()
                        TextField("0", text: $startReadingString)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                    }
                    
                    HStack {
                        Text("End Odometer")
                        Spacer()
                        TextField("0", text: $endReadingString)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                    }
                    
                    if let start = Int(startReadingString), let end = Int(endReadingString) {
                        HStack {
                            Text("Distance")
                            Spacer()
                            Text("\(end - start) mi").bold()
                                .foregroundColor(end >= start ? .primary : .red)
                        }
                    }
                }
                
                Section("Notes") {
                    TextField("Optional notes...", text: $notes)
                }
            }
            .navigationTitle(isEditing ? "Edit Trip" : "Log Trip")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .disabled(!isValid || isLoading)
                }
            }
            .task {
                await loadData()
            }
        }
    }
    
    private func loadData() async {
        guard !isDataLoaded else { return }
        guard let id = authManager.user?.id else { return }
        
        do {
            // 1. Fetch vehicles
            availableVehicles = try await vehicleManager.fetchVehicles(for: id)
            
            // 2. Populate fields if editing
            if let log = logToEdit {
                date = log.date
                selectedVehicleID = log.vehicleID
                startReadingString = String(log.startReading)
                endReadingString = String(log.endReading)
                purpose = log.purpose
                notes = log.notes ?? ""
            } else {
                // Default to first vehicle
                if let first = availableVehicles.first {
                    selectedVehicleID = first.id ?? ""
                }
            }
            isDataLoaded = true
        } catch { print(error) }
    }
    
    func save() {
        guard let instructorID = authManager.user?.id,
              let start = Int(startReadingString),
              let end = Int(endReadingString) else { return }
        
        isLoading = true
        
        let log = MileageLog(
            id: logToEdit?.id, // Preserve ID if editing
            instructorID: instructorID,
            vehicleID: selectedVehicleID,
            date: date,
            startReading: start,
            endReading: end,
            purpose: purpose,
            notes: notes.isEmpty ? nil : notes
        )
        
        Task {
            do {
                if isEditing {
                    try await vehicleManager.updateMileageLog(log)
                } else {
                    try await vehicleManager.addMileageLog(log)
                }
                onSave()
                dismiss()
            } catch {
                print("Error saving log: \(error)")
            }
            isLoading = false
        }
    }
}
