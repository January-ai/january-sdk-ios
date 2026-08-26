import SwiftUI

struct SectionLabel: View {
    let title: String
    let color: Color

    init(_ title: String, color: Color = AppPalette.muted) {
        self.title = title
        self.color = color
    }

    var body: some View {
        Text(title.uppercased())
            .font(AppTypography.eyebrow)
            .tracking(1.15)
            .foregroundStyle(color)
            .padding(.horizontal, 6)
            .accessibilityAddTraits(.isHeader)
    }
}

#Preview {
    SectionLabel("Nutrition facts")
        .padding()
        .background(AppPalette.paper)
}

