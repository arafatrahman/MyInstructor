// File: arafatrahman/myinstructor/MyInstructor-main/MyInstructor/Core/Managers/LocationManager.swift
// --- UPDATED: Disabled background updates to prevent crash (Enable Background Modes in Xcode to use) ---

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
    private var isSharing: Bool = false
    private var activeLessonID: String?
    private var activeUserRole: UserRole?

    override init() {
        self.authorizationStatus = locationManager.authorizationStatus
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBestForNavigation
        
        // --- CRITICAL FIX: ---
        // This line causes a crash if "Location updates" is not enabled in Xcode -> Signing & Capabilities -> Background Modes.
        // I have commented it out to stop the crash. Uncomment ONLY after enabling the capability in Xcode.
        locationManager.allowsBackgroundLocationUpdates = true
    }

    func requestLocation() async {
        if locationManager.authorizationStatus == .notDetermined {
            locationManager.requestWhenInUseAuthorization()
        }
        locationManager.requestLocation()
    }
    
    // MARK: - Live Sharing
    
    func startSharing(lessonID: String, role: UserRole) {
        print("LocationManager: Starting share for lesson \(lessonID) as \(role.rawValue)")
        self.activeLessonID = lessonID
        self.activeUserRole = role
        self.isSharing = true
        locationManager.startUpdatingLocation()
        
        // Mark lesson as active in Firestore
        db.collection("lessons").document(lessonID).updateData([
            "isLocationActive": true
        ])
    }
    
    func stopSharing() {
        print("LocationManager: Stopping share.")
        self.isSharing = false
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
        
        DispatchQueue.main.async {
            self.location = location
        }
        
        // --- Firestore Update ---
        if isSharing, let lessonID = activeLessonID, let role = activeUserRole {
            let lat = location.coordinate.latitude
            let lng = location.coordinate.longitude
            
            var data: [String: Any] = [:]
            if role == .instructor {
                data = ["instructorLat": lat, "instructorLng": lng]
            } else if role == .student {
                data = ["studentLat": lat, "studentLng": lng]
            }
            
            // Debounce or throttle could be added here for efficiency,
            // but for "Live" accuracy we update on change.
            db.collection("lessons").document(lessonID).updateData(data)
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("!!! LocationManager failed: \(error.localizedDescription)")
    }
    
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        DispatchQueue.main.async {
            self.authorizationStatus = manager.authorizationStatus
        }
    }
}
