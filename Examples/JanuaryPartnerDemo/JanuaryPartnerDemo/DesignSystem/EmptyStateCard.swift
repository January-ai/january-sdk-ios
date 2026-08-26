import SwiftUI

struct EmptyStateCard: View {
    let title: String
    let message: String
    let symbol: String

    var body: some View {
        HStack(spacing: 0) {
            Spacer(minLength: 0)
            VStack(spacing: 10) {
                Image(systemName: symbol)
                    .font(.system(size: 24, weight: .medium))
                    .foregroundStyle(AppPalette.green)
                Text(title)
                    .font(AppTypography.cardTitle)
                    .foregroundStyle(AppPalette.ink)
                    .multilineTextAlignment(.center)
                Text(message)
                    .font(AppTypography.body)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(AppPalette.body)
            }
            .padding(.horizontal, 20)
            Spacer(minLength: 0)
        }
        .padding(.vertical, 34)
        .background(AppPalette.surface, in: RoundedRectangle(cornerRadius: AppRadius.feature, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: AppRadius.feature, style: .continuous)
                .stroke(AppPalette.border, lineWidth: 1.5)
        }
    }
}

#Preview {
    EmptyStateCard(
        title: "Find a food",
        message: "Search January’s food database, then choose a serving and quantity.",
        symbol: "fork.knife"
    )
    .padding()
    .background(AppPalette.paper)
}
