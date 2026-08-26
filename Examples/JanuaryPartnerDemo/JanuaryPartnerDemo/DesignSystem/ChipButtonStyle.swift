import SwiftUI

struct ChipButtonStyle: ButtonStyle {
    let isSelected: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 15, weight: .bold))
            .foregroundStyle(isSelected ? AppPalette.paper : AppPalette.ink)
            .padding(.horizontal, 18)
            .frame(minHeight: 44)
            .background(
                isSelected ? AppPalette.ink : AppPalette.surface,
                in: RoundedRectangle(cornerRadius: AppRadius.control, style: .continuous)
            )
            .overlay {
                if !isSelected {
                    RoundedRectangle(cornerRadius: AppRadius.control, style: .continuous)
                        .stroke(AppPalette.border, lineWidth: 1.5)
                }
            }
            .opacity(configuration.isPressed ? 0.75 : 1)
    }
}

#Preview {
    HStack {
        Button("Selected", action: {}).buttonStyle(ChipButtonStyle(isSelected: true))
        Button("Default", action: {}).buttonStyle(ChipButtonStyle(isSelected: false))
    }
    .padding()
    .background(AppPalette.paper)
}
