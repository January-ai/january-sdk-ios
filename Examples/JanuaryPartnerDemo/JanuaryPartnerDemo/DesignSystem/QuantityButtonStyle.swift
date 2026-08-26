import SwiftUI

struct QuantityButtonStyle: ButtonStyle {
    var isPrimary = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 16, weight: .semibold))
            .foregroundStyle(isPrimary ? AppPalette.paper : AppPalette.ink)
            .frame(width: 44, height: 44)
            .background(
                (isPrimary ? AppPalette.ink : AppPalette.control).opacity(configuration.isPressed ? 0.72 : 1),
                in: Circle()
            )
            .overlay {
                if !isPrimary { Circle().stroke(AppPalette.border, lineWidth: 1.5) }
            }
    }
}

#Preview {
    HStack {
        Button("Decrease", systemImage: "minus", action: {})
            .labelStyle(.iconOnly)
            .buttonStyle(QuantityButtonStyle())
        Button("Increase", systemImage: "plus", action: {})
            .labelStyle(.iconOnly)
            .buttonStyle(QuantityButtonStyle(isPrimary: true))
    }
    .padding()
    .background(AppPalette.paper)
}
