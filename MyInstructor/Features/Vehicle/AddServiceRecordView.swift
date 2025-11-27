// File: arafatrahman/myinstructor/MyInstructor-main/MyInstructor/Features/Vehicle/AddServiceRecordView.swift
// --- UPDATED: Moved Save button to the top right toolbar ---

import SwiftUI

struct AddServiceRecordView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var vehicleManager: VehicleManager
    @EnvironmentObject var authManager: AuthManager
    
    var recordToEdit: ServiceRecord?
    var onSave: () -> Void
    
    // Form State
    @State private var date = Date()
    @State private var serviceType = ""
    @State private var garageName = ""
    @State private var mileageString = ""
    @State private var costString = ""
    @State private var notes = ""
    @State private var hasNextService = false
    @State private var nextServiceDate = Date().addingTimeInterval(31536000) // Default +1 year
    
    // Vehicle Selection
    @State private var availableVehicles: [Vehicle] = []
    @State private var selectedVehicleID: String = ""
    
    @State private var isLoading = false
    @State private var errorMessage: String?
    
    let commonTypes = ["Full Service", "Interim Service", "MOT", "Oil Change", "Tyres", "Repair", "Brakes"]
    
    var isEditing: Bool { recordToEdit != nil }
    
    // Validation Logic
    var isFormValid: Bool {
        !serviceType.isEmpty && !costString.isEmpty && !selectedVehicleID.isEmpty
    }
    
    var body: some View {
        NavigationView {
            Form {
                // MARK: - Vehicle Selection
                Section("Vehicle") {
                    if availableVehicles.isEmpty {
                        Text("No vehicles found. Please add one in 'My Vehicles'.")
                            .foregroundColor(.secondary)
                    } else {
                        Picker("Select Vehicle", selection: $selectedVehicleID) {
                            Text("Select a vehicle").tag("")
                            ForEach(availableVehicles) { vehicle in
                                Text(vehicle.displayName).tag(vehicle.id ?? "")
                            }
                        }
                    }
                }
                
                // MARK: - Service Details
                Section("Service Details") {
                    DatePicker("Date", selection: $date, displayedComponents: .date)
                    
                    HStack {
                        Text("Mileage")
                        Spacer()
                        TextField("e.g. 45000", text: $mileageString)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                    }
                    
                    Picker("Type", selection: $serviceType) {
                        Text("Select Type").tag("")
                        ForEach(commonTypes, id: \.self) { type in
                            Text(type).tag(type)
                        }
                    }
                    // Allow custom input if type is not in the list
                    if serviceType.isEmpty || !commonTypes.contains(serviceType) {
                        TextField("Custom Service Type", text: $serviceType)
                    }
                    
                    TextField("Garage / Center Name", text: $garageName)
                    
                    HStack {
                        Text("Cost (£)")
                        Spacer()
                        TextField("0.00", text: $costString)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                    }
                }
                
                // MARK: - Reminders
                Section("Reminders") {
                    Toggle("Schedule Next Service", isOn: $hasNextService)
                        .tint(.primaryBlue)
                    
                    if hasNextService {
                        DatePicker("Due Date", selection: $nextServiceDate, displayedComponents: .date)
                    }
                }
                
                // MARK: - Notes
                Section("Notes") {
                    TextEditor(text: $notes)
                        .frame(height: 80)
                }
                
                if let error = errorMessage {
                    Section {
                        Text(error).foregroundColor(.warningRed).font(.caption)
                    }
                }
            }
            .navigationTitle(isEditing ? "Edit Service" : "Add Service")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                // Cancel Button (Top Left)
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                
                // Save Button (Top Right)
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveRecord()
                    }
                    .bold()
                    .disabled(!isFormValid || isLoading)
                }
            }
            .task {
                await loadVehiclesAndData()
            }
        }
    }
    
    // MARK: - Logic
    
    private func loadVehiclesAndData() async {
        guard let instructorID = authManager.user?.id else { return }
        do {
            // 1. Fetch vehicles
            self.availableVehicles = try await vehicleManager.fetchVehicles(for: instructorID)
            
            // 2. Populate form if editing
            if let record = recordToEdit {
                date = record.date
                serviceType = record.serviceType
                garageName = record.garageName
                mileageString = String(record.mileage)
                costString = String(format: "%.2f", record.cost)
                notes = record.notes ?? ""
                selectedVehicleID = record.vehicleID ?? ""
                
                if let nextDate = record.nextServiceDate {
                    hasNextService = true
                    nextServiceDate = nextDate
                }
            } else {
                // If creating new, default to first vehicle if available
                if let first = availableVehicles.first?.id {
                    selectedVehicleID = first
                }
            }
        } catch {
            print("Error loading data: \(error)")
        }
    }
    
    private func saveRecord() {
        let safeCost = costString.replacingOccurrences(of: ",", with: ".")
        guard let instructorID = authManager.user?.id,
              let costVal = Double(safeCost),
              let mileageVal = Int(mileageString) else {
            errorMessage = "Invalid numeric values."
            return
        }
        
        isLoading = true
        let newRecord = ServiceRecord(
            id: recordToEdit?.id,
            instructorID: instructorID,
            vehicleID: selectedVehicleID,
            date: date,
            mileage: mileageVal,
            serviceType: serviceType.isEmpty ? "General Service" : serviceType,
            garageName: garageName,
            cost: costVal,
            notes: notes.isEmpty ? nil : notes,
            nextServiceDate: hasNextService ? nextServiceDate : nil
        )
        
        Task {
            do {
                if isEditing {
                    try await vehicleManager.updateServiceRecord(newRecord)
                } else {
                    try await vehicleManager.addServiceRecord(newRecord)
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
