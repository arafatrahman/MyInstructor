// File: MyInstructor/Core/Managers/LocationManager.swift
import Foundation
import CoreLocation
import Combine

// This class will manage getting the user's location
class LocationManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    private let locationManager = CLLocationManager()
    
    @Published var location: CLLocation? = nil
    @Published var authorizationStatus: CLAuthorizationStatus

    override init() {
        self.authorizationStatus = locationManager.authorizationStatus
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
    }

    /// Asks for permission and then requests the user's current location.
    func requestLocation() async {
        // Check if authorization status is not determined, then request it
        if locationManager.authorizationStatus == .notDetermined {
            locationManager.requestWhenInUseAuthorization()
        }
        
        // Request location. The delegate will handle the async response.
        locationManager.requestLocation()
    }
    
    // --- Delegate Methods ---
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        // Update our published location property
        DispatchQueue.main.async {
            self.location = locations.first
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("!!! LocationManager failed: \(error.localizedDescription)")
    }
    
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        // Update the published authorization status
        DispatchQueue.main.async {
            self.authorizationStatus = manager.authorizationStatus
        }
    }
}
