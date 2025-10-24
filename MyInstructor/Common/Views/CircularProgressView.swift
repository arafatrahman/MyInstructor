import SwiftUI

// Shared component for circular progress (Flow 6, 11, 12)
struct CircularProgressView: View {
    let progress: Double
    var color: Color = .primaryBlue
    var lineWidth: CGFloat = 8.0
    var size: CGFloat = 80
    
    var body: some View {
        ZStack {
            // Background track
            Circle()
                .stroke(lineWidth: lineWidth)
                .opacity(0.15)
                .foregroundColor(color)
            
            // Progress arc
            Circle()
                .trim(from: 0.0, to: CGFloat(min(progress, 1.0)))
                .stroke(style: StrokeStyle(lineWidth: lineWidth, lineCap: .round, lineJoin: .round))
                .foregroundColor(color)
                .rotationEffect(Angle(degrees: 270.0))
            
            Text("\(Int(progress * 100))%")
                .font(.subheadline).bold()
                .foregroundColor(.textDark)
        }
        .frame(width: size, height: size)
    }
}