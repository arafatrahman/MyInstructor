// File: arafatrahman/myinstructor/MyInstructor-main/MyInstructor/Features/Community/InstructorDirectoryView.swift
// --- UPDATED: Separated Search Bar and Filter Button to fix layout issues ---

import SwiftUI
import Combine
import MapKit
import CoreLocation

struct InstructorDirectoryView: View {
    @EnvironmentObject var communityManager: CommunityManager
    @EnvironmentObject var locationManager: LocationManager
    
    @State private var allInstructors: [Student] = []
    @State private var isLoading = true
    @State private var searchText = ""
    @State private var isShowingMapView = false
    
    // Computed property for filtering
    var filteredInstructors: [Student] {
        if searchText.isEmpty {
            return allInstructors
        }
        
        let lowercasedSearch = searchText.lowercased()
        return allInstructors.filter { instructor in
            let nameMatch = instructor.name.lowercased().contains(lowercasedSearch)
            let emailMatch = instructor.email.lowercased().contains(lowercasedSearch)
            let phoneMatch = (instructor.phone ?? "").lowercased().contains(lowercasedSearch)
            let schoolMatch = (instructor.drivingSchool ?? "").lowercased().contains(lowercasedSearch)
            
            return nameMatch || emailMatch || phoneMatch || schoolMatch
        }
    }
    
    @State private var mapRegion: MKCoordinateRegion = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 51.5074, longitude: -0.1278),
        span: MKCoordinateSpan(latitudeDelta: 0.1, longitudeDelta: 0.1)
    )

    var body: some View {
        VStack(spacing: 0) {
            
            // MARK: - Safe Area Spacer
            // Ensures content doesn't sit under the notch/dynamic island
            Color.clear
                .frame(height: 0)
                .background(Color(.systemBackground))
            
            // MARK: - Header Section
            VStack(spacing: 12) {
                // Search Row
                HStack(spacing: 12) {
                    // 1. Search Field Container
                    HStack(spacing: 8) {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(.secondary)
                        
                        TextField("Search instructors...", text: $searchText)
                            .foregroundColor(.primary)
                    }
                    .padding(.vertical, 12)
                    .padding(.horizontal, 16)
                    .background(Color(.secondarySystemBackground))
                    .cornerRadius(12)
                    
                    // 2. Filter Button (Separated)
                    Button {
                        // TODO: Open filter options
                    } label: {
                        Image(systemName: "slider.horizontal.3")
                            .font(.headline)
                            .foregroundColor(.primaryBlue)
                            .frame(width: 48, height: 48) // Fixed touch target
                            .background(Color(.secondarySystemBackground))
                            .cornerRadius(12)
                    }
                }
                .padding(.horizontal)
                .padding(.top, 10)
                
                // View Mode Toggle
                Picker("View Mode", selection: $isShowingMapView) {
                    Text("List").tag(false)
                    Text("Map").tag(true)
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)
                .padding(.bottom, 10)
            }
            .background(Color(.systemBackground))
            .shadow(color: Color.black.opacity(0.05), radius: 5, y: 5)
            .zIndex(1)
            
            // MARK: - Main Content
            if isLoading {
                Spacer()
                ProgressView("Finding Instructors...")
                Spacer()
            } else if isShowingMapView {
                // Map View
                Map(coordinateRegion: $mapRegion, annotationItems: allInstructors.filter { $0.coordinate != nil }) { instructor in
                    MapAnnotation(coordinate: instructor.coordinate!) {
                        NavigationLink(destination: InstructorPublicProfileView(instructorID: instructor.id ?? "")) {
                            VStack(spacing: 0) {
                                AsyncImage(url: URL(string: instructor.photoURL ?? "")) { phase in
                                    if let image = phase.image {
                                        image.resizable().scaledToFill()
                                    } else {
                                        Image(systemName: "car.circle.fill").resizable().foregroundColor(.primaryBlue)
                                    }
                                }
                                .frame(width: 40, height: 40)
                                .clipShape(Circle())
                                .overlay(Circle().stroke(Color.white, lineWidth: 2))
                                .shadow(radius: 3)
                                
                                Image(systemName: "arrowtriangle.down.fill")
                                    .font(.caption2)
                                    .foregroundColor(.white)
                                    .offset(y: -4)
                                    .shadow(radius: 2)
                            }
                        }
                    }
                }
                .ignoresSafeArea(edges: .bottom)
                
            } else {
                // List View
                if filteredInstructors.isEmpty {
                    Spacer()
                    EmptyStateView(icon: "magnifyingglass", message: "No instructors found.")
                    Spacer()
                } else {
                    ScrollView {
                        LazyVStack(spacing: 16) {
                            ForEach(filteredInstructors) { instructor in
                                NavigationLink {
                                    InstructorPublicProfileView(instructorID: instructor.id ?? "")
                                } label: {
                                    InstructorDirectoryCard(instructor: instructor)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding()
                        .padding(.bottom, 20)
                    }
                    .background(Color(.systemGroupedBackground))
                }
            }
        }
        .navigationTitle("Find Instructors")
        .navigationBarTitleDisplayMode(.inline)
        .task { await loadData() }
    }
    
    // MARK: - Data Helpers
    func loadData() async {
        isLoading = true
        var instructors: [Student] = []
        do {
            instructors = try await communityManager.fetchInstructorDirectory(filters: [:])
        } catch { print("Failed to fetch: \(error)") }
        
        instructors = await geocodeInstructors(instructors)
        
        if let userLocation = locationManager.location {
            instructors = sortInstructorsByDistance(instructors, from: userLocation)
            withAnimation {
                mapRegion.center = userLocation.coordinate
                mapRegion.span = MKCoordinateSpan(latitudeDelta: 0.1, longitudeDelta: 0.1)
            }
        } else if let first = instructors.first(where: { $0.coordinate != nil })?.coordinate {
            withAnimation { mapRegion.center = first }
        }
        
        self.allInstructors = instructors
        isLoading = false
    }

    func geocodeInstructors(_ instructors: [Student]) async -> [Student] {
        let geocoder = CLGeocoder()
        var geocodedInstructors: [Student] = []
        await withTaskGroup(of: Student.self) { group in
            for var instructor in instructors {
                group.addTask {
                    if let address = instructor.address, !address.isEmpty {
                        do {
                            let placemarks = try await geocoder.geocodeAddressString(address)
                            if let location = placemarks.first?.location {
                                instructor.coordinate = location.coordinate
                            }
                        } catch { }
                    }
                    return instructor
                }
            }
            for await instructor in group { geocodedInstructors.append(instructor) }
        }
        return geocodedInstructors
    }
    
    func sortInstructorsByDistance(_ instructors: [Student], from userLocation: CLLocation) -> [Student] {
        var sorted = instructors
        for i in 0..<sorted.count {
            if let coord = sorted[i].coordinate {
                let loc = CLLocation(latitude: coord.latitude, longitude: coord.longitude)
                sorted[i].distance = userLocation.distance(from: loc)
            }
        }
        sorted.sort { ($0.distance ?? Double.greatestFiniteMagnitude) < ($1.distance ?? Double.greatestFiniteMagnitude) }
        return sorted
    }
}

// MARK: - Card Component
struct InstructorDirectoryCard: View {
    let instructor: Student
    
    var body: some View {
        HStack(alignment: .top, spacing: 15) {
            // Avatar
            AsyncImage(url: URL(string: instructor.photoURL ?? "")) { phase in
                if let image = phase.image {
                    image.resizable().scaledToFill()
                } else {
                    Image(systemName: "person.circle.fill")
                        .resizable().scaledToFit()
                        .foregroundColor(.primaryBlue.opacity(0.3))
                }
            }
            .frame(width: 65, height: 65)
            .clipShape(Circle())
            .overlay(Circle().stroke(Color(.systemGray5), lineWidth: 1))
            
            // Info Column
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(instructor.name)
                        .font(.headline)
                        .foregroundColor(.primary)
                        .lineLimit(1)
                    
                    Spacer()
                    
                    HStack(spacing: 3) {
                        Image(systemName: "star.fill").font(.caption2)
                        Text("4.8").font(.caption).bold()
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.yellow.opacity(0.2))
                    .foregroundColor(.orange)
                    .clipShape(Capsule())
                }
                
                Text(instructor.drivingSchool ?? "Independent Instructor")
                    .font(.subheadline)
                    .foregroundColor(.accentGreen)
                    .fontWeight(.medium)
                
                HStack(spacing: 4) {
                    Image(systemName: "mappin.and.ellipse")
                        .font(.caption)
                        .foregroundColor(.gray)
                    Text(instructor.address ?? "Location hidden")
                        .font(.caption)
                        .foregroundColor(.gray)
                        .lineLimit(1)
                }
            }
        }
        .padding(16)
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 4)
    }
}
