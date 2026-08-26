import SwiftUI

struct SecondaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: 0) {
            Spacer(minLength: 12)
            configuration.label
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(isEnabled ? AppPalette.ink : AppPalette.subdued)
            Spacer(minLength: 12)
        }
        .frame(minHeight: 54)
        .background(
            AppPalette.control.opacity(configuration.isPressed ? 0.75 : 1),
            in: RoundedRectangle(cornerRadius: AppRadius.control, style: .continuous)
        )
    }
}

#Preview {
    Button("Choose photo", action: {})
        .buttonStyle(SecondaryButtonStyle())
        .padding()
        .background(AppPalette.paper)
}
