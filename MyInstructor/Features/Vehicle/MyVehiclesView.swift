// File: arafatrahman/myinstructor/MyInstructor-main/MyInstructor/Features/Vehicle/MyVehiclesView.swift
// --- UPDATED: Added "Upcoming MOT & Insurance" cards to the top ---

import SwiftUI
import PhotosUI

struct MyVehiclesView: View {
    @EnvironmentObject var vehicleManager: VehicleManager
    @EnvironmentObject var authManager: AuthManager
    @Environment(\.dismiss) var dismiss
    
    @State private var vehicles: [Vehicle] = []
    @State private var isLoading = true
    @State private var isAddSheetPresented = false
    @State private var vehicleToEdit: Vehicle? = nil
    
    // --- COMPUTED PROPERTIES FOR TOP CARDS ---
    
    // Find the vehicle with the nearest (or most overdue) MOT
    var nearestMOT: (Vehicle, Date)? {
        vehicles.compactMap { v -> (Vehicle, Date)? in
            guard let date = v.motExpiry else { return nil }
            return (v, date)
        }
        .sorted { $0.1 < $1.1 } // Sort ascending (oldest/nearest first)
        .first
    }
    
    // Find the vehicle with the nearest (or most overdue) Insurance
    var nearestInsurance: (Vehicle, Date)? {
        vehicles.compactMap { v -> (Vehicle, Date)? in
            guard let date = v.insuranceExpiry else { return nil }
            return (v, date)
        }
        .sorted { $0.1 < $1.1 }
        .first
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                
                // MARK: - Top Summary Cards
                if !vehicles.isEmpty && (nearestMOT != nil || nearestInsurance != nil) {
                    HStack(spacing: 12) {
                        // MOT Card
                        if let (veh, date) = nearestMOT {
                            ExpiryCard(type: "MOT", vehicleName: veh.displayName, date: date, icon: "wrench.and.screwdriver.fill")
                        } else {
                            ExpiryCardPlaceholder(type: "MOT", icon: "wrench.and.screwdriver.fill")
                        }
                        
                        // Insurance Card
                        if let (veh, date) = nearestInsurance {
                            ExpiryCard(type: "Insurance", vehicleName: veh.displayName, date: date, icon: "shield.fill")
                        } else {
                            ExpiryCardPlaceholder(type: "Insurance", icon: "shield.fill")
                        }
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 10)
                    .background(Color(.secondarySystemGroupedBackground)) // Subtle separator
                }
                
                // MARK: - Vehicle List
                if isLoading {
                    Spacer()
                    ProgressView("Loading Vehicles...")
                    Spacer()
                } else if vehicles.isEmpty {
                    EmptyStateView(
                        icon: "car.2.fill",
                        message: "No vehicles added yet.",
                        actionTitle: "Add Vehicle",
                        action: { isAddSheetPresented = true }
                    )
                } else {
                    List {
                        ForEach(vehicles) { vehicle in
                            Button {
                                vehicleToEdit = vehicle
                            } label: {
                                HStack(spacing: 15) {
                                    // Vehicle Photo Thumbnail
                                    if let photoURL = vehicle.photoURLs?.first, let url = URL(string: photoURL) {
                                        AsyncImage(url: url) { phase in
                                            if let image = phase.image {
                                                image.resizable().scaledToFill()
                                            } else {
                                                Color.gray.opacity(0.3)
                                            }
                                        }
                                        .frame(width: 60, height: 60)
                                        .clipShape(RoundedRectangle(cornerRadius: 8))
                                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.gray.opacity(0.2), lineWidth: 1))
                                    } else {
                                        // Fallback Icon
                                        Image(systemName: "car.fill")
                                            .resizable()
                                            .scaledToFit()
                                            .frame(width: 30, height: 30)
                                            .padding(15)
                                            .background(Color.secondaryGray)
                                            .clipShape(RoundedRectangle(cornerRadius: 8))
                                            .foregroundColor(.primaryBlue)
                                    }
                                    
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(vehicle.displayName)
                                            .font(.headline)
                                        
                                        Text("License: \(vehicle.licensePlate)")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                        
                                        // List badges
                                        HStack(spacing: 5) {
                                            if let mot = vehicle.motExpiry {
                                                ExpiryBadge(title: "MOT", date: mot)
                                            }
                                            if let ins = vehicle.insuranceExpiry {
                                                ExpiryBadge(title: "INS", date: ins)
                                            }
                                        }
                                    }
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                        .foregroundColor(.gray)
                                }
                            }
                            .buttonStyle(.plain)
                            .swipeActions(edge: .trailing) {
                                Button(role: .destructive) {
                                    Task { await deleteVehicle(vehicle) }
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                        }
                    }
                    .listStyle(.insetGrouped)
                }
            }
            .navigationTitle("My Vehicles")
            .navigationBarTitleDisplayMode(.inline)
            .background(Color(.systemGroupedBackground)) // Match list background
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
                    Button { isAddSheetPresented = true } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $isAddSheetPresented) {
                AddVehicleFormView(onSave: { Task { await fetchData() } })
            }
            .sheet(item: $vehicleToEdit) { vehicle in
                AddVehicleFormView(vehicleToEdit: vehicle, onSave: {
                    vehicleToEdit = nil
                    Task { await fetchData() }
                })
            }
            .task { await fetchData() }
        }
    }
    
    func fetchData() async {
        guard let id = authManager.user?.id else { return }
        isLoading = true
        do {
            vehicles = try await vehicleManager.fetchVehicles(for: id)
        } catch { print("Error: \(error)") }
        isLoading = false
    }
    
    func deleteVehicle(_ vehicle: Vehicle) async {
        guard let id = vehicle.id else { return }
        try? await vehicleManager.deleteVehicle(id: id)
        withAnimation { vehicles.removeAll { $0.id == id } }
    }
}

// MARK: - New Card Components

struct ExpiryCard: View {
    let type: String
    let vehicleName: String
    let date: Date
    let icon: String
    
    var daysRemaining: Int {
        Calendar.current.dateComponents([.day], from: Date(), to: date).day ?? 0
    }
    
    var urgencyColor: Color {
        if daysRemaining < 0 { return .warningRed } // Expired
        if daysRemaining < 30 { return .orange }    // Due soon
        return .accentGreen                         // Safe
    }
    
    var statusText: String {
        if daysRemaining < 0 { return "Expired" }
        if daysRemaining == 0 { return "Due Today" }
        return "In \(daysRemaining) days"
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(urgencyColor)
                Text(type)
                    .font(.caption).bold()
                    .foregroundColor(.secondary)
                Spacer()
            }
            
            Text(date.formatted(date: .abbreviated, time: .omitted))
                .font(.headline)
            
            Text(vehicleName)
                .font(.caption)
                .lineLimit(1)
                .foregroundColor(.secondary)
            
            Spacer()
            
            Text(statusText)
                .font(.caption).bold()
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(urgencyColor.opacity(0.15))
                .foregroundColor(urgencyColor)
                .cornerRadius(4)
        }
        .padding(12)
        .frame(maxWidth: .infinity, maxHeight: 120) // Fixed height for uniformity
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.05), radius: 4, x: 0, y: 2)
    }
}

struct ExpiryCardPlaceholder: View {
    let type: String
    let icon: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(.secondary)
                Text(type)
                    .font(.caption).bold()
                    .foregroundColor(.secondary)
                Spacer()
            }
            Spacer()
            Text("No Data")
                .font(.subheadline)
                .foregroundColor(.textLight)
            Spacer()
        }
        .padding(12)
        .frame(maxWidth: .infinity, maxHeight: 120)
        .background(Color(.systemBackground).opacity(0.5))
        .cornerRadius(12)
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.secondary.opacity(0.1), style: StrokeStyle(lineWidth: 1, dash: [5])))
    }
}

// Reuse existing ExpiryBadge for the list
struct ExpiryBadge: View {
    let title: String
    let date: Date
    
    var isExpired: Bool { date < Date() }
    var isSoon: Bool { date < Date().addingTimeInterval(60*60*24*30) } // 30 days
    
    var color: Color {
        if isExpired { return .warningRed }
        if isSoon { return .orange }
        return .accentGreen
    }
    
    var body: some View {
        Text("\(title): \(date.formatted(date: .numeric, time: .omitted))")
            .font(.system(size: 9, weight: .bold))
            .padding(.horizontal, 4)
            .padding(.vertical, 2)
            .background(color.opacity(0.15))
            .foregroundColor(color)
            .cornerRadius(4)
    }
}

// MARK: - Add/Edit Form with Photos (UNCHANGED from previous, but included for completeness)
struct AddVehicleFormView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var vehicleManager: VehicleManager
    @EnvironmentObject var authManager: AuthManager
    
    var vehicleToEdit: Vehicle?
    var onSave: () -> Void
    
    @State private var make = ""
    @State private var model = ""
    @State private var year = ""
    @State private var licensePlate = ""
    @State private var nickname = ""
    @State private var isLoading = false
    
    // Photos State
    @State private var selectedItems: [PhotosPickerItem] = []
    @State private var selectedPhotoData: Data? = nil
    @State private var existingPhotoURLs: [String] = []
    
    // Expiry Dates
    @State private var hasInsurance = false
    @State private var insuranceDate = Date()
    
    @State private var hasMOT = false
    @State private var motDate = Date()
    
    var isEditing: Bool { vehicleToEdit != nil }
    var isValid: Bool { !make.isEmpty && !model.isEmpty && !licensePlate.isEmpty }
    
    var body: some View {
        NavigationView {
            Form {
                // Photos Section
                Section {
                    HStack {
                        Spacer()
                        VStack {
                            if let data = selectedPhotoData, let uiImage = UIImage(data: data) {
                                Image(uiImage: uiImage)
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: 120, height: 80)
                                    .clipShape(RoundedRectangle(cornerRadius: 10))
                                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.primaryBlue, lineWidth: 2))
                            } else if let urlString = existingPhotoURLs.first, let url = URL(string: urlString) {
                                AsyncImage(url: url) { phase in
                                    if let image = phase.image {
                                        image.resizable().scaledToFill()
                                    } else {
                                        ProgressView()
                                    }
                                }
                                .frame(width: 120, height: 80)
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                            } else {
                                Image(systemName: "car.circle")
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 80, height: 80)
                                    .foregroundColor(.secondaryGray)
                            }
                            
                            PhotosPicker(selection: $selectedItems, maxSelectionCount: 1, matching: .images) {
                                Text(selectedPhotoData != nil || !existingPhotoURLs.isEmpty ? "Change Photo" : "Add Photo")
                                    .font(.subheadline)
                                    .foregroundColor(.primaryBlue)
                            }
                            .onChange(of: selectedItems) { newItems in
                                Task {
                                    if let item = newItems.first,
                                       let data = try? await item.loadTransferable(type: Data.self) {
                                        withAnimation {
                                            selectedPhotoData = data
                                        }
                                    }
                                }
                            }
                        }
                        Spacer()
                    }
                    .padding(.vertical, 10)
                }
                .listRowBackground(Color.clear)
                
                // Vehicle Details
                Section("Vehicle Details") {
                    HStack {
                        Text("Make")
                        Spacer()
                        TextField("e.g. Toyota", text: $make).multilineTextAlignment(.trailing)
                    }
                    HStack {
                        Text("Model")
                        Spacer()
                        TextField("e.g. Corolla", text: $model).multilineTextAlignment(.trailing)
                    }
                    HStack {
                        Text("Year")
                        Spacer()
                        TextField("YYYY", text: $year).keyboardType(.numberPad).multilineTextAlignment(.trailing)
                    }
                    HStack {
                        Text("License Plate")
                        Spacer()
                        TextField("Required", text: $licensePlate).multilineTextAlignment(.trailing)
                    }
                    HStack {
                        Text("Nickname")
                        Spacer()
                        TextField("Optional", text: $nickname).multilineTextAlignment(.trailing)
                    }
                }
                
                // Reminders & Expiry
                Section("Reminders & Expiry") {
                    Toggle("Insurance Expiry", isOn: $hasInsurance).tint(.primaryBlue)
                    if hasInsurance {
                        DatePicker("Insurance Date", selection: $insuranceDate, displayedComponents: .date).labelsHidden()
                    }
                    Toggle("MOT Expiry", isOn: $hasMOT).tint(.primaryBlue)
                    if hasMOT {
                        DatePicker("MOT Date", selection: $motDate, displayedComponents: .date).labelsHidden()
                    }
                }
            }
            .navigationTitle(isEditing ? "Edit Vehicle" : "Add Vehicle")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button { saveVehicle() } label: {
                        if isLoading { ProgressView() } else { Text("Save").bold() }
                    }
                    .disabled(!isValid || isLoading)
                }
            }
            .onAppear {
                if let v = vehicleToEdit {
                    make = v.make; model = v.model; year = v.year; licensePlate = v.licensePlate; nickname = v.nickname ?? ""; existingPhotoURLs = v.photoURLs ?? []
                    if let insurance = v.insuranceExpiry { hasInsurance = true; insuranceDate = insurance }
                    if let mot = v.motExpiry { hasMOT = true; motDate = mot }
                }
            }
        }
    }
    
    private func saveVehicle() {
        guard let instructorID = authManager.user?.id else { return }
        isLoading = true
        Task {
            var finalPhotoURLs = existingPhotoURLs
            if let data = selectedPhotoData {
                do {
                    let url = try await StorageManager.shared.uploadVehiclePhoto(photoData: data, userID: instructorID)
                    finalPhotoURLs = [url]
                } catch { print("Failed to upload vehicle photo: \(error)") }
            }
            let vehicle = Vehicle(
                id: vehicleToEdit?.id,
                instructorID: instructorID,
                make: make,
                model: model,
                year: year,
                licensePlate: licensePlate,
                nickname: nickname.isEmpty ? nil : nickname,
                photoURLs: finalPhotoURLs.isEmpty ? nil : finalPhotoURLs,
                insuranceExpiry: hasInsurance ? insuranceDate : nil,
                motExpiry: hasMOT ? motDate : nil
            )
            try? await (isEditing ? vehicleManager.updateVehicle(vehicle) : vehicleManager.addVehicle(vehicle))
            onSave()
            dismiss()
            isLoading = false
        }
    }
}
