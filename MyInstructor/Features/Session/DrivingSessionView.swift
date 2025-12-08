// File: arafatrahman/myinstructor/MyInstructor-main/MyInstructor/Features/Session/DrivingSessionView.swift
// --- UPDATED: Ensures Role is loaded before listening, and adds Lesson ID check ---

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
    @State private var otherUserRole: String = "..." // Placeholder until loaded
    private let db = Firestore.firestore()
    @State private var listener: ListenerRegistration?
    
    // Timer
    let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    
    @State private var position: MapCameraPosition = .userLocation(fallback: .automatic)

    var body: some View {
        ZStack(alignment: .top) {
            // MARK: - Live Map
            Map(position: $position) {
                UserAnnotation() // Show Me (System Blue Dot)
                
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
                        // Connection Status
                        HStack {
                            Circle()
                                .fill(locationManager.isSharing ? Color.green : Color.orange)
                                .frame(width: 8, height: 8)
                                .shadow(radius: 2)
                            
                            Text(locationManager.isSharing ? "LIVE" : "CONNECTING...")
                                .font(.caption).bold().foregroundColor(.white)
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.black.opacity(0.6))
                        .cornerRadius(8)
                        
                        Text(lesson.topic)
                            .font(.title3).bold().foregroundColor(.white)
                            .shadow(radius: 2)
                        
                        // Distance & ETA
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
                            HStack(spacing: 6) {
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
                    
                    // Timer
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
                
                // MARK: - Debug Status Bar
                HStack(spacing: 15) {
                    // 1. My GPS Status
                    HStack(spacing: 4) {
                        Image(systemName: locationManager.location != nil ? "location.fill" : "location.slash.fill")
                            .foregroundColor(locationManager.location != nil ? .green : .red)
                        Text(locationManager.location != nil ? "GPS OK" : "No GPS")
                    }
                    
                    Divider().frame(height: 12).background(Color.white)
                    
                    // 2. Lesson ID Match Check
                    // Both users MUST see the same code here (e.g. #A1B2)
                    HStack(spacing: 4) {
                        Image(systemName: "number")
                            .foregroundColor(.white)
                        Text(lesson.id?.suffix(4) ?? "????")
                    }
                    
                    Divider().frame(height: 12).background(Color.white)
                    
                    // 3. Other User Status
                    HStack(spacing: 4) {
                        Image(systemName: otherUserLocation != nil ? "person.wave.2.fill" : "person.slash.fill")
                            .foregroundColor(otherUserLocation != nil ? .green : .orange)
                        Text(otherUserLocation != nil ? "Linked" : "Waiting")
                    }
                }
                .font(.caption2).bold().foregroundColor(.white)
                .padding(10)
                .background(Color.black.opacity(0.75))
                .cornerRadius(20)
                .padding(.bottom, 10)
                
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
            // Wait for auth to be fully ready before starting ANYTHING
            startSessionSequence()
        }
        .onDisappear {
            stopListening()
        }
        .onReceive(timer) { _ in
            if isActive { timeElapsed += 1 }
        }
        // Auto-center map logic
        .onChange(of: otherUserLocation) { oldVal, newVal in
            if let newVal = newVal, let myLoc = locationManager.location?.coordinate {
                withAnimation {
                    // Create region fitting both points
                    let centerLat = (myLoc.latitude + newVal.latitude) / 2
                    let centerLng = (myLoc.longitude + newVal.longitude) / 2
                    let latDelta = abs(myLoc.latitude - newVal.latitude) * 1.4
                    let lngDelta = abs(myLoc.longitude - newVal.longitude) * 1.4
                    
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
        if let user = authManager.user {
            // User is loaded, we can start safely
            let myRole = user.role
            self.otherUserRole = (myRole == .instructor) ? "Student" : "Instructor"
            
            print("DrivingSessionView: Auth Ready. My Role: \(myRole). Listening for: \(self.otherUserRole)")
            
            // 1. Listen for other person
            startListening(myRole: myRole)
            
            // 2. Share my location
            startSharing(user: user)
        } else {
            // Not ready, retry in 0.5s
            print("DrivingSessionView: Waiting for AuthManager...")
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                self.startSessionSequence()
            }
        }
    }
    
    func startSharing(user: AppUser) {
        guard let lessonID = lesson.id else { return }
        
        locationManager.startSharing(lessonID: lessonID, role: user.role)
        
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
    }
    
    func startListening(myRole: UserRole) {
        guard let lessonID = lesson.id else { return }
        
        listener = db.collection("lessons").document(lessonID)
            .addSnapshotListener { snapshot, error in
                if let error = error { print("DrivingSessionView Error: \(error)"); return }
                guard let data = snapshot?.data() else { return }
                
                var lat: Double?
                var lng: Double?
                
                // Logic: If I am Instructor, I read Student data.
                if myRole == .instructor {
                    lat = data["studentLat"] as? Double
                    lng = data["studentLng"] as? Double
                } else {
                    lat = data["instructorLat"] as? Double
                    lng = data["instructorLng"] as? Double
                }
                
                if let lat = lat, let lng = lng {
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
    var iconName: String { role == .instructor ? "car.circle.fill" : "person.circle.fill" }
    var color: Color { role == .instructor ? .primaryBlue : .accentGreen }
    
    var body: some View {
        Image(systemName: iconName)
            .font(.title).foregroundColor(color)
            .padding(6).background(Color.white).clipShape(Circle())
            .shadow(radius: 4)
            .overlay(Circle().stroke(color.opacity(0.8), lineWidth: 2))
            .scaleEffect(isMe ? 1.2 : 1.1)
    }
}
