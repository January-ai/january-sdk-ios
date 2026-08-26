import SwiftUI

struct PrimaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: 0) {
            Spacer(minLength: 16)
            configuration.label
                .font(AppTypography.bodyStrong)
                .foregroundStyle(isEnabled ? AppPalette.paper : AppPalette.subdued)
            Spacer(minLength: 16)
        }
        .frame(minHeight: 56)
        .background(
            (isEnabled ? AppPalette.ink : AppPalette.control).opacity(configuration.isPressed ? 0.82 : 1),
            in: RoundedRectangle(cornerRadius: AppRadius.control, style: .continuous)
        )
        .scaleEffect(configuration.isPressed ? 0.985 : 1)
    }
}

struct PrimaryButton: View {
    let title: String
    var systemImage: String? = nil
    var isLoading = false
    var isDisabled = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack {
                buttonLabel.opacity(isLoading ? 0 : 1)
                if isLoading { LoadingSpinner() }
            }
        }
        .buttonStyle(PrimaryButtonStyle())
        .disabled(isDisabled)
        .allowsHitTesting(!isLoading)
        .accessibilityLabel(title)
        .accessibilityValue(isLoading ? "Loading" : "")
    }

    @ViewBuilder
    private var buttonLabel: some View {
        if let systemImage { Label(title, systemImage: systemImage) } else { Text(title) }
    }
}

#Preview("Primary button states") {
    VStack(spacing: 16) {
        PrimaryButton(title: "Analyze meal", systemImage: "camera", action: {})
        PrimaryButton(title: "Finding alternatives", isLoading: true, action: {})
        PrimaryButton(title: "Unavailable", isDisabled: true, action: {})
    }
    .padding()
    .background(AppPalette.paper)
}
