// File: arafatrahman/myinstructor/MyInstructor-main/MyInstructor/Core/Managers/LocationManager.swift
// --- UPDATED: Removed distanceFilter for smoother live updates & added published isSharing state ---

import Foundation
import CoreLocation
import Combine
import FirebaseFirestore

class LocationManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    private let locationManager = CLLocationManager()
    private let db = Firestore.firestore()
    
    @Published var location: CLLocation? = nil
    @Published var authorizationStatus: CLAuthorizationStatus
    
    // --- Sharing State ---
    @Published var isSharing: Bool = false // Now Published so UI can react
    private var activeLessonID: String?
    private var activeUserRole: UserRole?

    override init() {
        self.authorizationStatus = locationManager.authorizationStatus
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBestForNavigation
        // locationManager.distanceFilter = 10 // REMOVED: Get every update for smooth live view
        
        // --- CRITICAL: If you have enabled Background Modes in Xcode, uncomment this ---
        // locationManager.allowsBackgroundLocationUpdates = true
        // locationManager.pausesLocationUpdatesAutomatically = false
    }

    func requestLocation() async {
        if locationManager.authorizationStatus == .notDetermined {
            locationManager.requestWhenInUseAuthorization()
        }
        locationManager.requestLocation()
    }
    
    // MARK: - Live Sharing
    
    func startSharing(lessonID: String, role: UserRole) {
        print("LocationManager: START sharing for lesson \(lessonID) as \(role.rawValue)")
        self.activeLessonID = lessonID
        self.activeUserRole = role
        
        DispatchQueue.main.async {
            self.isSharing = true
        }
        
        locationManager.startUpdatingLocation()
        
        // Mark lesson as active in Firestore immediately
        db.collection("lessons").document(lessonID).updateData([
            "isLocationActive": true
        ]) { error in
            if let error = error { print("LocationManager: Error activating lesson: \(error)") }
        }
    }
    
    func stopSharing() {
        print("LocationManager: STOP sharing.")
        
        DispatchQueue.main.async {
            self.isSharing = false
        }
        
        locationManager.stopUpdatingLocation()
        
        if let lessonID = activeLessonID {
            // Mark lesson as inactive
            db.collection("lessons").document(lessonID).updateData([
                "isLocationActive": false
            ])
        }
        
        self.activeLessonID = nil
        self.activeUserRole = nil
    }
    
    // MARK: - Delegate Methods
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        
        // Update local state
        DispatchQueue.main.async {
            self.location = location
        }
        
        // --- Firestore Update ---
        // Verify we have all necessary data to write
        if isSharing, let lessonID = activeLessonID, let role = activeUserRole {
            let lat = location.coordinate.latitude
            let lng = location.coordinate.longitude
            
            // Construct data based on role
            var data: [String: Any] = [:]
            
            if role == .instructor {
                data = ["instructorLat": lat, "instructorLng": lng]
            } else if role == .student {
                data = ["studentLat": lat, "studentLng": lng]
            } else {
                print("LocationManager Warning: Unknown role, cannot save location.")
                return
            }
            
            // Write to Firestore
            db.collection("lessons").document(lessonID).updateData(data) { error in
                if let error = error {
                    print("LocationManager Write Error: \(error.localizedDescription)")
                }
            }
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("!!! LocationManager failed: \(error.localizedDescription)")
    }
    
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        DispatchQueue.main.async {
            self.authorizationStatus = manager.authorizationStatus
        }
        print("LocationManager: Auth status changed to \(manager.authorizationStatus.rawValue)")
    }
}
