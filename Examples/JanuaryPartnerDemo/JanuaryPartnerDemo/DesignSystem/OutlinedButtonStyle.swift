import SwiftUI

struct OutlinedButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: 0) {
            Spacer(minLength: 12)
            configuration.label
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(AppPalette.ink)
            Spacer(minLength: 12)
        }
        .frame(minHeight: 52)
        .background(AppPalette.surface, in: RoundedRectangle(cornerRadius: AppRadius.control, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: AppRadius.control, style: .continuous)
                .stroke(AppPalette.border, lineWidth: 1.5)
        }
        .opacity(configuration.isPressed ? 0.72 : 1)
    }
}

#Preview {
    Button("Use image URL", action: {})
        .buttonStyle(OutlinedButtonStyle())
        .padding()
        .background(AppPalette.paper)
}
