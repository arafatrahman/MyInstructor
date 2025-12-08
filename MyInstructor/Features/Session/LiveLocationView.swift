// File: arafatrahman/myinstructor/MyInstructor-main/MyInstructor/Features/Session/LiveLocationView.swift
// --- UPDATED: Added missing LocationPin, PinType, and UI helpers ---

import SwiftUI
import MapKit
import FirebaseFirestore
import UIKit

struct LiveLocationView: View {
    @State var lesson: Lesson // Can be a placeholder
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var authManager: AuthManager
    @EnvironmentObject var lessonManager: LessonManager
    @EnvironmentObject var dataService: DataService
    
    // Map State
    @State private var region = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 51.5074, longitude: -0.1278),
        span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
    )
    
    // Live Coordinates
    @State private var instructorLocation: CLLocationCoordinate2D?
    @State private var studentLocation: CLLocationCoordinate2D?
    
    // Selection State (If lesson is generic)
    @State private var availableLessons: [Lesson] = []
    @State private var selectedLessonID: String = ""
    @State private var isSelectionMode: Bool = false
    
    @State private var showStartLesson = false
    @State private var showSelectLessonSheet = false
    
    private let db = Firestore.firestore()

    var isInstructor: Bool { authManager.role == .instructor }
    
    var effectiveLessonID: String {
        return lesson.id ?? ""
    }

    var body: some View {
        ZStack(alignment: .topTrailing) {
            // MARK: - Map
            Map(coordinateRegion: $region, annotationItems: getAnnotations()) { pin in
                MapAnnotation(coordinate: pin.coordinate) {
                    Image(systemName: pin.type == .instructor ? "car.fill" : "person.circle.fill")
                        .font(.title)
                        .foregroundColor(pin.type == .instructor ? .primaryBlue : .accentGreen)
                        .padding(5)
                        .background(Color.white)
                        .clipShape(Circle())
                        .shadow(radius: 4)
                }
            }
            .ignoresSafeArea()
            
            // MARK: - Controls
            VStack {
                // Top Bar
                HStack {
                    if isSelectionMode {
                        Button {
                            showSelectLessonSheet = true
                        } label: {
                            HStack {
                                Text(lesson.topic == "Live Mode" || lesson.topic == "Live Tracking" ? "Select Lesson" : lesson.topic)
                                    .fontWeight(.bold)
                                Image(systemName: "chevron.down")
                            }
                            .padding()
                            .background(.ultraThinMaterial)
                            .cornerRadius(20)
                        }
                    } else {
                        Text(lesson.topic)
                            .font(.headline)
                            .padding()
                            .background(.ultraThinMaterial)
                            .cornerRadius(20)
                    }
                    
                    Spacer()
                    
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.largeTitle)
                            .foregroundColor(.textDark)
                            .background(Color.white.clipShape(Circle()))
                    }
                }
                .padding(.top, 50)
                .padding(.horizontal)
                
                Spacer()
                
                // Bottom Action Sheet
                VStack(spacing: 15) {
                    if let sLoc = studentLocation, let iLoc = instructorLocation {
                        let distance = calculateDistance(from: sLoc, to: iLoc)
                        Text("Distance: \(distance, specifier: "%.2f") km")
                            .font(.headline)
                            .foregroundColor(.gray)
                    } else {
                        Text("Waiting for location updates...")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        if isInstructor {
                            Button {
                                if validLessonSelected() {
                                    showStartLesson = true
                                } else {
                                    showSelectLessonSheet = true
                                }
                            } label: {
                                Text("Start Lesson")
                                    .font(.headline)
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(Color.primaryBlue)
                                    .foregroundColor(.white)
                                    .cornerRadius(12)
                            }
                        } else {
                            Button {
                                if validLessonSelected() {
                                    showStartLesson = true // Student "joins" the active view
                                }
                            } label: {
                                Text("Join Session")
                                    .font(.headline)
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(Color.accentGreen)
                                    .foregroundColor(.white)
                                    .cornerRadius(12)
                            }
                        }
                    }
                }
                .padding(20)
                .background(Color(.systemBackground))
                .cornerRadius(20, corners: [.topLeft, .topRight])
                .shadow(radius: 10)
            }
        }
        .onAppear {
            setupView()
        }
        .sheet(isPresented: $showSelectLessonSheet) {
            NavigationView {
                List(availableLessons) { item in
                    Button {
                        self.lesson = item
                        self.selectedLessonID = item.id ?? ""
                        listenToLesson(item.id ?? "")
                        showSelectLessonSheet = false
                    } label: {
                        VStack(alignment: .leading) {
                            Text(item.topic).font(.headline)
                            Text(item.startTime.formatted(date: .abbreviated, time: .shortened)).font(.caption)
                        }
                    }
                }
                .navigationTitle("Select Lesson to Share")
                .toolbar { Button("Cancel") { showSelectLessonSheet = false } }
            }
            .presentationDetents([.medium])
        }
        .fullScreenCover(isPresented: $showStartLesson) {
            DrivingSessionView(lesson: lesson)
        }
    }
    
    // MARK: - Logic
    
    func setupView() {
        // If passed lesson has no ID (e.g. Tab Bar "Live Map"), fetch today's lessons
        if lesson.id == nil || lesson.id == "" {
            isSelectionMode = true
            Task {
                await fetchTodaysLessons()
            }
        } else {
            // Specific lesson passed (e.g. from Profile)
            isSelectionMode = false
            selectedLessonID = lesson.id ?? ""
            listenToLesson(selectedLessonID)
        }
    }
    
    func validLessonSelected() -> Bool {
        return !selectedLessonID.isEmpty
    }
    
    func fetchTodaysLessons() async {
        guard let uid = authManager.user?.id else { return }
        // Fetch upcoming
        if let upcoming = try? await lessonManager.fetchUpcomingLessons(for: uid) {
            self.availableLessons = upcoming
        }
    }
    
    func listenToLesson(_ id: String) {
        db.collection("lessons").document(id)
            .addSnapshotListener { snapshot, error in
                guard let data = snapshot?.data() else { return }
                
                // Update Instructor Pin
                if let lat = data["instructorLat"] as? Double,
                   let lng = data["instructorLng"] as? Double {
                    self.instructorLocation = CLLocationCoordinate2D(latitude: lat, longitude: lng)
                }
                
                // Update Student Pin
                if let lat = data["studentLat"] as? Double,
                   let lng = data["studentLng"] as? Double {
                    self.studentLocation = CLLocationCoordinate2D(latitude: lat, longitude: lng)
                }
                
                // Auto-center map if we have points
                if let iLoc = instructorLocation {
                    withAnimation {
                        region.center = iLoc
                    }
                }
            }
    }
    
    func getAnnotations() -> [LocationPin] {
        var pins: [LocationPin] = []
        if let iLoc = instructorLocation {
            pins.append(LocationPin(name: "Instructor", coordinate: iLoc, type: .instructor))
        }
        if let sLoc = studentLocation {
            pins.append(LocationPin(name: "Student", coordinate: sLoc, type: .student))
        }
        return pins
    }
    
    func calculateDistance(from: CLLocationCoordinate2D, to: CLLocationCoordinate2D) -> Double {
        let loc1 = CLLocation(latitude: from.latitude, longitude: from.longitude)
        let loc2 = CLLocation(latitude: to.latitude, longitude: to.longitude)
        return loc1.distance(from: loc2) / 1000.0 // km
    }
}

// MARK: - Models & Helpers

struct LocationPin: Identifiable {
    let id = UUID()
    let name: String
    let coordinate: CLLocationCoordinate2D
    let type: PinType
}

enum PinType {
    case instructor, student
}

// Helper for corner radius on specific corners (Requires import UIKit)
extension View {
    func cornerRadius(_ radius: CGFloat, corners: UIRectCorner) -> some View {
        clipShape(RoundedCorner(radius: radius, corners: corners))
    }
}

struct RoundedCorner: Shape {
    var radius: CGFloat = .infinity
    var corners: UIRectCorner = .allCorners
    
    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(roundedRect: rect, byRoundingCorners: corners, cornerRadii: CGSize(width: radius, height: radius))
        return Path(path.cgPath)
    }
}
