import SwiftUI

struct ScanPhotoInstructions: View {
    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: "camera.fill")
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(AppPalette.green)
                .frame(width: 44, height: 44)
                .background(
                    AppPalette.green.opacity(0.1),
                    in: RoundedRectangle(cornerRadius: 14, style: .continuous)
                )

            VStack(alignment: .leading, spacing: 6) {
                Text("Photograph the entire meal")
                    .font(AppTypography.cardTitle)
                Text("January identifies foods, servings, and nutrition — then estimates glucose impact.")
                    .font(AppTypography.body)
                    .foregroundStyle(AppPalette.body)
            }

            Spacer(minLength: 0)
        }
        .appCard()
    }
}

#Preview {
    ScanPhotoInstructions()
        .padding()
        .background(AppPalette.paper)
}
