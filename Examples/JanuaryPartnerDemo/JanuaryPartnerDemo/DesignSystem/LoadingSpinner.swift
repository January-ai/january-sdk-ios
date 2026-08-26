import SwiftUI

struct LoadingSpinner: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isRotating = false

    var color: Color = AppPalette.paper
    var size: CGFloat = 22

    var body: some View {
        Circle()
            .trim(from: 0.12, to: 0.78)
            .stroke(color, style: StrokeStyle(lineWidth: 3, lineCap: .round))
            .frame(width: size, height: size)
            .rotationEffect(.degrees(isRotating ? 360 : 0))
            .animation(reduceMotion ? nil : .linear(duration: 0.75).repeatForever(autoreverses: false), value: isRotating)
            .onAppear { isRotating = !reduceMotion }
            .onDisappear { isRotating = false }
            .accessibilityHidden(true)
    }
}

#Preview {
    HStack(spacing: 24) {
        LoadingSpinner()
            .padding(20)
            .background(AppPalette.ink, in: Circle())
        LoadingSpinner(color: AppPalette.green, size: 30)
    }
}
