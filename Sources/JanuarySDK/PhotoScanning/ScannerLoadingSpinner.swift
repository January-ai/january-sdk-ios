import SwiftUI

struct ScannerLoadingSpinner: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isRotating = false

    var body: some View {
        Circle()
            .trim(from: 0.12, to: 0.78)
            .stroke(.white, style: StrokeStyle(lineWidth: 3, lineCap: .round))
            .frame(width: 30, height: 30)
            .rotationEffect(.degrees(isRotating ? 360 : 0))
            .animation(
                reduceMotion ? nil : .linear(duration: 0.75).repeatForever(autoreverses: false),
                value: isRotating
            )
            .onAppear { isRotating = !reduceMotion }
            .onDisappear { isRotating = false }
            .accessibilityHidden(true)
    }
}

private struct ScannerLoadingSpinnerPreview: PreviewProvider {
    static var previews: some View {
        ScannerLoadingSpinner()
            .padding(24)
            .background(Color.black)
            .previewLayout(.sizeThatFits)
    }
}
