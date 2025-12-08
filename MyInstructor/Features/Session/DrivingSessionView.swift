// File: arafatrahman/myinstructor/MyInstructor-main/MyInstructor/Features/Session/DrivingSessionView.swift
// --- UPDATED: Robust sharing logic, removed input, added status indicators ---

import SwiftUI
import MapKit
import Combine
import FirebaseFirestore

// Extension for Equatable Coordinates
extension CLLocationCoordinate2D: Equatable {
    public static func == (lhs: CLLocationCoordinate2D, rhs: CLLocationCoordinate2D) -> Bool {
        return lhs.latitude == rhs.latitude && lhs.longitude == rhs.longitude
    }
}

struct DrivingSessionView: View {
    @State var lesson: Lesson
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var lessonManager: LessonManager
    @EnvironmentObject var locationManager: LocationManager
    @EnvironmentObject var authManager: AuthManager
    
    @State private var timeElapsed: TimeInterval = 0
    @State private var isActive: Bool = true
    
    // --- Other User Tracking ---
    @State private var otherUserLocation: CLLocationCoordinate2D?
    @State private var otherUserRole: String = "" // "Instructor" or "Student"
    private let db = Firestore.firestore()
    @State private var listener: ListenerRegistration?
    
    // Timer
    let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    
    // Map State
    @State private var position: MapCameraPosition = .userLocation(fallback: .automatic)

    var body: some View {
        ZStack(alignment: .top) {
            // MARK: - Live Map
            Map(position: $position) {
                // 1. Show ME (Native System Blue Dot)
                UserAnnotation()
                
                // 2. Show THEM (Custom Pin)
                if let otherLoc = otherUserLocation {
                    Annotation(otherUserRole, coordinate: otherLoc) {
                        let role = (otherUserRole == "Instructor") ? UserRole.instructor : UserRole.student
                        UserPinView(role: role, isMe: false)
                    }
                }
            }
            .mapControls {
                MapUserLocationButton()
                MapCompass()
            }
            .ignoresSafeArea()
            
            // MARK: - Top Info Overlay
            VStack(spacing: 0) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 6) {
                        // Status Badge
                        HStack {
                            Circle()
                                .fill(locationManager.isSharing ? Color.green : Color.orange)
                                .frame(width: 8, height: 8)
                                .shadow(radius: 2)
                            
                            Text(locationManager.isSharing ? "SHARING LIVE" : "CONNECTING...")
                                .font(.caption).bold().foregroundColor(.white)
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.black.opacity(0.6))
                        .cornerRadius(8)
                        
                        Text(lesson.topic)
                            .font(.title3).bold().foregroundColor(.white)
                            .shadow(radius: 2)
                        
                        // Distance & ETA Display
                        if let myLoc = locationManager.location?.coordinate, let theirLoc = otherUserLocation {
                            let distance = calculateDistance(from: myLoc, to: theirLoc)
                            let eta = calculateETA(for: distance)
                            
                            HStack(spacing: 10) {
                                Label("\(distance, specifier: "%.2f") km", systemImage: "arrow.triangle.swap")
                                Label("ETA: \(eta)", systemImage: "timer")
                            }
                            .font(.caption).bold()
                            .foregroundColor(.white)
                            .padding(8)
                            .background(Color.black.opacity(0.6))
                            .cornerRadius(8)
                        } else {
                            // Waiting State
                            HStack {
                                ProgressView().tint(.white).scaleEffect(0.7)
                                Text("Waiting for \(otherUserRole)...")
                                    .font(.caption)
                                    .foregroundColor(.white.opacity(0.8))
                            }
                            .padding(6)
                            .background(Color.black.opacity(0.4))
                            .cornerRadius(6)
                        }
                    }
                    
                    Spacer()
                    
                    // Timer Display
                    Text(timeString(from: timeElapsed))
                        .font(.title2).monospacedDigit().bold()
                        .foregroundColor(.white)
                        .padding(10)
                        .background(Color.black.opacity(0.4))
                        .cornerRadius(10)
                }
                .padding(.horizontal)
                .padding(.top, 60)
                .padding(.bottom, 20)
                
                Spacer()
            }
            .ignoresSafeArea()
            
            // MARK: - Bottom Controls
            VStack {
                Spacer()
                
                // End Button
                Button {
                    endSession()
                } label: {
                    Text("End Session")
                        .font(.headline).bold()
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.warningRed)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                }
                .padding(.horizontal, 40)
                .padding(.bottom, 40)
            }
        }
        .onAppear {
            startSessionSequence()
        }
        .onDisappear {
            stopListening()
        }
        .onReceive(timer) { _ in
            if isActive { timeElapsed += 1 }
        }
        // Auto-center map when other user moves
        .onChange(of: otherUserLocation) { oldVal, newVal in
            if let newVal = newVal, let myLoc = locationManager.location?.coordinate {
                withAnimation {
                    // Create region fitting both points
                    let centerLat = (myLoc.latitude + newVal.latitude) / 2
                    let centerLng = (myLoc.longitude + newVal.longitude) / 2
                    let latDelta = abs(myLoc.latitude - newVal.latitude) * 1.5
                    let lngDelta = abs(myLoc.longitude - newVal.longitude) * 1.5
                    
                    position = .region(MKCoordinateRegion(
                        center: CLLocationCoordinate2D(latitude: centerLat, longitude: centerLng),
                        span: MKCoordinateSpan(latitudeDelta: max(latDelta, 0.005), longitudeDelta: max(lngDelta, 0.005))
                    ))
                }
            }
        }
    }
    
    // MARK: - Logic & Actions
    
    func startSessionSequence() {
        // 1. Determine Roles for Listening
        let myRole = authManager.role
        self.otherUserRole = (myRole == .instructor) ? "Student" : "Instructor"
        
        // 2. Start Listening for Other
        startListening(myRole: myRole)
        
        // 3. Start Sharing My Location (with retry if user data isn't ready)
        attemptStartSharing()
    }
    
    func attemptStartSharing() {
        guard let lessonID = lesson.id else { return }
        
        if let user = authManager.user {
            // User loaded, start sharing
            locationManager.startSharing(lessonID: lessonID, role: user.role)
            
            // Notify only once
            let recipientID = (user.role == .instructor) ? lesson.studentID : lesson.instructorID
            if recipientID != user.id {
                NotificationManager.shared.sendNotification(
                    to: recipientID,
                    title: "Live Tracking Active",
                    message: "\(user.name ?? "User") is now sharing live location.",
                    type: "location",
                    relatedID: lessonID
                )
            }
        } else {
            // User not loaded yet, retry in 0.5s
            print("DrivingSessionView: User not ready, retrying startSharing...")
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                self.attemptStartSharing()
            }
        }
    }
    
    func startListening(myRole: UserRole) {
        guard let lessonID = lesson.id else { return }
        
        print("DrivingSessionView: Listening for \(otherUserRole) on lesson \(lessonID)")
        
        listener = db.collection("lessons").document(lessonID)
            .addSnapshotListener { snapshot, error in
                guard let data = snapshot?.data() else { return }
                
                var lat: Double?
                var lng: Double?
                
                if myRole == .instructor {
                    // I am Instructor, read Student Lat/Lng
                    lat = data["studentLat"] as? Double
                    lng = data["studentLng"] as? Double
                } else {
                    // I am Student, read Instructor Lat/Lng
                    lat = data["instructorLat"] as? Double
                    lng = data["instructorLng"] as? Double
                }
                
                if let lat = lat, let lng = lng {
                    // Update other user location
                    self.otherUserLocation = CLLocationCoordinate2D(latitude: lat, longitude: lng)
                }
            }
    }
    
    func stopListening() {
        listener?.remove()
        listener = nil
    }
    
    func endSession() {
        isActive = false
        locationManager.stopSharing()
        dismiss()
    }
    
    // MARK: - Helpers
    
    func timeString(from totalSeconds: TimeInterval) -> String {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.hour, .minute, .second]
        formatter.unitsStyle = .positional
        formatter.zeroFormattingBehavior = .pad
        return formatter.string(from: totalSeconds) ?? "00:00"
    }
    
    func calculateDistance(from: CLLocationCoordinate2D, to: CLLocationCoordinate2D) -> Double {
        let loc1 = CLLocation(latitude: from.latitude, longitude: from.longitude)
        let loc2 = CLLocation(latitude: to.latitude, longitude: to.longitude)
        return loc1.distance(from: loc2) / 1000.0 // km
    }
    
    func calculateETA(for distanceKM: Double) -> String {
        let speedKmH = 30.0
        let hours = distanceKM / speedKmH
        let minutes = Int(hours * 60)
        if minutes < 1 { return "< 1 min" }
        if minutes > 60 {
            let h = minutes / 60
            let m = minutes % 60
            return "\(h)h \(m)m"
        }
        return "\(minutes) min"
    }
}

// MARK: - Custom Pin View
struct UserPinView: View {
    let role: UserRole
    let isMe: Bool
    
    var iconName: String {
        role == .instructor ? "car.circle.fill" : "person.circle.fill"
    }
    
    var color: Color {
        return role == .instructor ? .primaryBlue : .accentGreen
    }
    
    var body: some View {
        Image(systemName: iconName)
            .font(.title)
            .foregroundColor(color)
            .padding(6)
            .background(Color.white)
            .clipShape(Circle())
            .shadow(radius: 4)
            .overlay(Circle().stroke(color.opacity(0.8), lineWidth: 2))
            .scaleEffect(isMe ? 1.2 : 1.1)
    }
}
