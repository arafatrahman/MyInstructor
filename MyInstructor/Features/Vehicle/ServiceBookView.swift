import SwiftUI

struct ServiceBookView: View {
    @EnvironmentObject var vehicleManager: VehicleManager
    @EnvironmentObject var authManager: AuthManager
    
    @State private var serviceRecords: [ServiceRecord] = []
    @State private var isLoading = true
    @State private var isAddSheetPresented = false
    @State private var recordToEdit: ServiceRecord? = nil
    
    // Calculate next service (closest future date)
    var nextService: ServiceRecord? {
        let futureServices = serviceRecords.compactMap { $0.nextServiceDate }
            .filter { $0 > Date() }
            .sorted()
        
        guard let nextDate = futureServices.first else { return nil }
        // Find the record that corresponds to this date (optional logic)
        return serviceRecords.first(where: { $0.nextServiceDate == nextDate })
    }

    var body: some View {
        NavigationView {
            VStack(spacing: 15) {
                
                // MARK: - Next Service Card
                if let nextDate = nextService?.nextServiceDate {
                    HStack {
                        VStack(alignment: .leading, spacing: 5) {
                            Text("Next Service Due")
                                .font(.subheadline)
                                .foregroundColor(.white.opacity(0.9))
                            Text(nextDate, style: .date)
                                .font(.title2).bold()
                                .foregroundColor(.white)
                            if let days = Calendar.current.dateComponents([.day], from: Date(), to: nextDate).day {
                                Text("In \(days) days")
                                    .font(.caption)
                                    .foregroundColor(.white.opacity(0.8))
                            }
                        }
                        Spacer()
                        Image(systemName: "wrench.and.screwdriver.fill")
                            .font(.largeTitle)
                            .foregroundColor(.white.opacity(0.2))
                    }
                    .padding()
                    .background(Color.primaryBlue)
                    .cornerRadius(16)
                    .padding(.horizontal)
                    .shadow(color: Color.primaryBlue.opacity(0.3), radius: 8, x: 0, y: 4)
                }
                
                // MARK: - History List
                if isLoading {
                    Spacer()
                    ProgressView("Loading History...")
                    Spacer()
                } else if serviceRecords.isEmpty {
                    Spacer()
                    EmptyStateView(icon: "book.closed.fill", message: "No service history yet.")
                    Spacer()
                } else {
                    List {
                        ForEach(serviceRecords) { record in
                            Button {
                                recordToEdit = record
                            } label: {
                                ServiceRecordRow(record: record)
                            }
                            .buttonStyle(.plain)
                            .listRowSeparator(.hidden)
                            .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
                            .swipeActions(edge: .trailing) {
                                Button(role: .destructive) {
                                    Task { await deleteRecord(record.id!) }
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                        }
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("Service Book")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button { isAddSheetPresented = true } label: {
                        Image(systemName: "plus").font(.headline.bold())
                    }
                }
            }
            .sheet(isPresented: $isAddSheetPresented) {
                AddServiceRecordView(onSave: { Task { await fetchData() } })
            }
            .sheet(item: $recordToEdit) { record in
                AddServiceRecordView(recordToEdit: record, onSave: {
                    recordToEdit = nil
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
            serviceRecords = try await vehicleManager.fetchServiceRecords(for: id)
        } catch { print("Error fetching services: \(error)") }
        isLoading = false
    }
    
    func deleteRecord(_ id: String) async {
        try? await vehicleManager.deleteServiceRecord(id: id)
        withAnimation { serviceRecords.removeAll { $0.id == id } }
    }
}

struct ServiceRecordRow: View {
    let record: ServiceRecord
    
    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle().fill(Color.primaryBlue.opacity(0.1)).frame(width: 45, height: 45)
                Image(systemName: "car.fill") // Or dynamic icon based on type
                    .foregroundColor(.primaryBlue)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(record.serviceType).font(.headline)
                Text(record.date.formatted(date: .abbreviated, time: .omitted))
                    .font(.caption).foregroundColor(.secondary)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 4) {
                Text(record.cost, format: .currency(code: "GBP"))
                    .font(.headline)
                Text("\(record.mileage) mi")
                    .font(.caption2).padding(4)
                    .background(Color(.systemGray6)).cornerRadius(4)
                    .foregroundColor(.secondary)
            }
        }
        .padding(12)
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.03), radius: 5, y: 2)
    }
}
