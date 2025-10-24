import SwiftUI
import MapKit
import UIKit // <--- ADDED for UIRectCorner access

// Flow Item 9: Live Location View (Pre-lesson rendezvous)
struct LiveLocationView: View {
    let lesson: Lesson
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var authManager: AuthManager
    
    // Mock Coordinates
    @State private var instructorLocation = CLLocationCoordinate2D(latitude: 51.5074, longitude: -0.1278)
    @State private var studentLocation = CLLocationCoordinate2D(latitude: 51.5150, longitude: -0.1180)
    
    @State private var region: MKCoordinateRegion = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 51.5112, longitude: -0.1229),
        span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
    )
    
    @State private var eta: Int = 8
    @State private var distance: Double = 1.1
    @State private var showStartLesson = false

    private var isInstructor: Bool {
        authManager.role == .instructor
    }

    var body: some View {
        ZStack(alignment: .topTrailing) {
            // Full-screen Map
            Map(coordinateRegion: $region, annotationItems: [
                LocationPin(name: "Instructor", coordinate: instructorLocation, type: .instructor),
                LocationPin(name: "Student", coordinate: studentLocation, type: .student)
            ]) { pin in
                MapAnnotation(coordinate: pin.coordinate) {
                    Image(systemName: pin.type == .instructor ? "car.fill" : "circle.fill")
                        .font(.title2)
                        .foregroundColor(pin.type == .instructor ? .primaryBlue : .accentGreen)
                        .padding(5)
                        .background(.white)
                        .clipShape(Circle())
                        .shadow(radius: 5)
                }
            }
            .ignoresSafeArea()
            
            // Custom Back Button
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.largeTitle)
                    .foregroundColor(.textDark)
                    .padding(5)
                    .background(.white)
                    .clipShape(Circle())
                    .shadow(radius: 5)
            }
            .padding(.top, 50)
            .padding(.trailing, 20)
            
            // Bottom Sheet
            VStack(spacing: 0) {
                // Passed isInstructor to the bottom sheet content
                LiveMapBottomSheet(eta: eta, distance: distance, lesson: lesson, isInstructor: isInstructor)
                
                // Action Button based on Role
                HStack {
                    if isInstructor {
                        Button {
                            showStartLesson = true
                        } label: {
                            Text("Start Lesson")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.primaryDrivingApp)
                    } else {
                        Button {
                            print("Student status: I'm Ready")
                        } label: {
                            Text("I'm Ready")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.primaryDrivingApp)
                    }
                }
                .padding(.horizontal)
                .padding(.vertical, 20)
            }
            .background(Color(.systemBackground))
            .cornerRadius(20, corners: [.topLeft, .topRight]) // Corrected usage
            .shadow(color: .textDark.opacity(0.2), radius: 10)
            .frame(maxHeight: 250)
            .frame(maxHeight: .infinity, alignment: .bottom)
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 1.5)) {
                region = MKCoordinateRegion(
                    center: CLLocationCoordinate2D(latitude: 51.5112, longitude: -0.1229),
                    span: MKCoordinateSpan(latitudeDelta: 0.02, longitudeDelta: 0.02)
                )
            }
        }
        .fullScreenCover(isPresented: $showStartLesson) {
            DrivingSessionView(lesson: lesson)
        }
    }
}

// Map Annotation Item
struct LocationPin: Identifiable {
    let id = UUID()
    let name: String
    let coordinate: CLLocationCoordinate2D
    let type: PinType
}

enum PinType {
    case instructor, student
}

// Bottom Sheet Content
struct LiveMapBottomSheet: View {
    let eta: Int
    let distance: Double
    let lesson: Lesson
    let isInstructor: Bool // <--- ADDED property
    
    var body: some View {
        VStack(alignment: .leading, spacing: 15) {
            Text("Lesson starts in \(eta) mins.")
                .font(.title2).bold()
                .foregroundColor(.primaryBlue)
            
            HStack {
                VStack(alignment: .leading) {
                    Text(isInstructor ? "Student Location" : "Instructor Location") // Uses isInstructor
                        .font(.headline)
                    Text(lesson.pickupLocation)
                        .font(.subheadline)
                        .foregroundColor(.textLight)
                }
                Spacer()
                
                VStack(alignment: .trailing) {
                    Text("\(distance, specifier: "%.1f") km")
                        .font(.headline)
                    Text("Distance")
                        .font(.subheadline)
                        .foregroundColor(.textLight)
                }
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
    }
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
