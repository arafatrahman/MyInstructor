// File: arafatrahman/myinstructor/MyInstructor-main/MyInstructor/Features/Vehicle/MyVehiclesView.swift
// --- UPDATED: Added Back button, Photo Picker, and Photo Display in List ---

import SwiftUI
import PhotosUI

struct MyVehiclesView: View {
    @EnvironmentObject var vehicleManager: VehicleManager
    @EnvironmentObject var authManager: AuthManager
    @Environment(\.dismiss) var dismiss // For the Back button
    
    @State private var vehicles: [Vehicle] = []
    @State private var isLoading = true
    @State private var isAddSheetPresented = false
    @State private var vehicleToEdit: Vehicle? = nil
    
    var body: some View {
        NavigationView {
            VStack {
                if isLoading {
                    ProgressView("Loading Vehicles...")
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
                                    // --- NEW: Vehicle Photo Thumbnail ---
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
            .toolbar {
                // --- NEW: Back Button (Upper Left) ---
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
        // Optional: Delete photos from storage here if you want strict cleanup
        try? await vehicleManager.deleteVehicle(id: id)
        withAnimation { vehicles.removeAll { $0.id == id } }
    }
}

// MARK: - Add/Edit Form with Photos
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
    
    // --- NEW: Photos State ---
    @State private var selectedItems: [PhotosPickerItem] = []
    @State private var selectedPhotoData: Data? = nil
    @State private var existingPhotoURLs: [String] = [] // Keep track of existing photos
    
    var isEditing: Bool { vehicleToEdit != nil }
    var isValid: Bool { !make.isEmpty && !model.isEmpty && !licensePlate.isEmpty }
    
    var body: some View {
        NavigationView {
            Form {
                // --- NEW: Photos Section ---
                Section {
                    HStack {
                        Spacer()
                        VStack {
                            if let data = selectedPhotoData, let uiImage = UIImage(data: data) {
                                // Show newly selected photo
                                Image(uiImage: uiImage)
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: 120, height: 80)
                                    .clipShape(RoundedRectangle(cornerRadius: 10))
                                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.primaryBlue, lineWidth: 2))
                            } else if let urlString = existingPhotoURLs.first, let url = URL(string: urlString) {
                                // Show existing photo
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
                                // Placeholder
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
                
                Section("Vehicle Details") {
                    TextField("Make (e.g. Toyota)", text: $make)
                    TextField("Model (e.g. Corolla)", text: $model)
                    TextField("Year", text: $year).keyboardType(.numberPad)
                    TextField("License Plate", text: $licensePlate)
                    TextField("Nickname (Optional)", text: $nickname)
                }
                
                Button {
                    saveVehicle()
                } label: {
                    if isLoading { ProgressView().tint(.white) } else { Text(isEditing ? "Save Changes" : "Add Vehicle") }
                }
                .disabled(!isValid || isLoading)
                .buttonStyle(.primaryDrivingApp)
                .listRowBackground(Color.clear)
            }
            .navigationTitle(isEditing ? "Edit Vehicle" : "Add Vehicle")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
            }
            .onAppear {
                if let v = vehicleToEdit {
                    make = v.make
                    model = v.model
                    year = v.year
                    licensePlate = v.licensePlate
                    nickname = v.nickname ?? ""
                    existingPhotoURLs = v.photoURLs ?? []
                }
            }
        }
    }
    
    private func saveVehicle() {
        guard let instructorID = authManager.user?.id else { return }
        isLoading = true
        
        Task {
            // 1. Upload Photo if selected
            var finalPhotoURLs = existingPhotoURLs
            
            if let data = selectedPhotoData {
                do {
                    let url = try await StorageManager.shared.uploadVehiclePhoto(photoData: data, userID: instructorID)
                    // For simplicity, we just replace the list with the new photo (single photo mode)
                    finalPhotoURLs = [url]
                } catch {
                    print("Failed to upload vehicle photo: \(error)")
                    // Proceed without photo if upload fails? Or return?
                    // Let's proceed for now.
                }
            }
            
            // 2. Create Vehicle Object
            let vehicle = Vehicle(
                id: vehicleToEdit?.id,
                instructorID: instructorID,
                make: make,
                model: model,
                year: year,
                licensePlate: licensePlate,
                nickname: nickname.isEmpty ? nil : nickname,
                photoURLs: finalPhotoURLs.isEmpty ? nil : finalPhotoURLs
            )
            
            // 3. Save to Firestore
            try? await (isEditing ? vehicleManager.updateVehicle(vehicle) : vehicleManager.addVehicle(vehicle))
            
            onSave()
            dismiss()
            isLoading = false
        }
    }
}
