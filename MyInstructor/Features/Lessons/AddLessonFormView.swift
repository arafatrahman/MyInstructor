import SwiftUI

struct AddLessonFormView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var lessonManager: LessonManager
    @EnvironmentObject var dataService: DataService 
    
    var onLessonAdded: () -> Void 
    
    // Form State
    @State private var topic: String = ""
    @State private var selectedStudent: Student? = nil 
    @State private var startTime: Date = Date().addingTimeInterval(3600) 
    @State private var durationHours: Double = 1.0 
    @State private var pickupLocation: String = ""
    @State private var fee: String = "45.00"
    
    @State private var availableStudents: [Student] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    
    private var durationSeconds: TimeInterval {
        durationHours * 3600
    }
    
    var body: some View {
        NavigationView {
            Form {
                // MARK: - Lesson Details
                Section("Lesson Details") {
                    TextField("Topic (e.g., Roundabouts, Parking)", text: $topic)
                    
                    Picker("Student", selection: $selectedStudent) {
                        Text("Select Student").tag(nil as Student?)
                        ForEach(availableStudents) { student in
                            Text(student.name).tag(student as Student?)
                        }
                    }
                    
                    DatePicker("Date & Time", selection: $startTime, displayedComponents: [.date, .hourAndMinute])
                        .datePickerStyle(.compact)
                    
                    // Duration Slider
                    VStack(alignment: .leading) {
                        Text("Duration: \(durationHours, specifier: "%.1f") hours")
                            .font(.subheadline).bold()
                        Slider(value: $durationHours, in: 0.5...3.0, step: 0.5)
                            .tint(.primaryBlue)
                    }
                }
                
                // MARK: - Location & Payment
                Section("Location & Fee") {
                    TextField("Pickup Location", text: $pickupLocation)
                        .textContentType(.fullStreetAddress)
                    
                    HStack {
                        Text("Fee (£)")
                        Spacer()
                        TextField("Amount", text: $fee)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                    }
                }
                
                // MARK: - Actions
                Section {
                    if let error = errorMessage {
                        Text(error).foregroundColor(.warningRed)
                    }
                    
                    Button {
                        addLessonAction()
                    } label: {
                        HStack {
                            if isLoading {
                                ProgressView().tint(.white)
                            } else {
                                Text("Schedule Lesson")
                            }
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.primaryDrivingApp)
                    .disabled(!isFormValid || isLoading)
                    .listRowBackground(Color.clear)
                }
            }
            .navigationTitle("Add New Lesson")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                }
            }
            .task {
                await fetchStudents()
            }
        }
    }
    
    private var isFormValid: Bool {
        !topic.isEmpty && selectedStudent != nil && !pickupLocation.isEmpty && (Double(fee) ?? 0 > 0)
    }
    
    private func fetchStudents() async {
        do {
            // NOTE: Mocking instructor ID
            availableStudents = try await dataService.fetchStudents(for: "i_auth_id")
            selectedStudent = availableStudents.first 
        } catch {
            errorMessage = "Failed to load students."
        }
    }
    
    private func addLessonAction() {
        guard let student = selectedStudent, let instructorID = "i_auth_id" as? String else { return } 
        
        isLoading = true
        errorMessage = nil
        
        let newLesson = Lesson(
            instructorID: instructorID,
            studentID: student.id ?? "unknown",
            topic: topic,
            startTime: startTime,
            duration: durationSeconds,
            pickupLocation: pickupLocation,
            fee: Double(fee) ?? 0.0,
            notes: nil
        )
        
        Task {
            do {
                try await lessonManager.addLesson(newLesson: newLesson)
                onLessonAdded()
                dismiss()
            } catch {
                errorMessage = "Failed to schedule lesson: \(error.localizedDescription)"
            }
            isLoading = false
        }
    }
}