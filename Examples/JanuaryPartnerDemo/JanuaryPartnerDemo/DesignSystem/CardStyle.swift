import SwiftUI

struct CardModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(AppSpacing.card)
            .background(AppPalette.surface, in: RoundedRectangle(cornerRadius: AppRadius.card, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: AppRadius.card, style: .continuous)
                    .stroke(AppPalette.ink.opacity(0.06), lineWidth: 1)
            }
            .shadow(color: AppPalette.ink.opacity(0.08), radius: 20, y: 10)
    }
}

extension View {
    func appCard() -> some View { modifier(CardModifier()) }
    func appBackground() -> some View { background(AppPalette.paper) }
}

#Preview {
    Text("Reusable card content")
        .foregroundStyle(AppPalette.ink)
        .appCard()
        .padding()
        .background(AppPalette.paper)
}
