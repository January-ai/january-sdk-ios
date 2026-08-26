import SwiftUI

struct ScanImagePreview<Content: View>: View {
    private let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        RoundedRectangle(cornerRadius: AppRadius.feature, style: .continuous)
            .fill(AppPalette.control)
            .frame(height: 240)
            .overlay {
                content
            }
            .clipShape(RoundedRectangle(cornerRadius: AppRadius.feature, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: AppRadius.feature, style: .continuous)
                    .stroke(AppPalette.border, lineWidth: 1.5)
            }
    }
}

#Preview {
    ScanImagePreview {
        Image(systemName: "fork.knife")
            .font(.largeTitle)
            .foregroundStyle(AppPalette.green)
    }
    .padding()
    .background(AppPalette.paper)
}
