import SwiftUI

struct SearchField: View {
    let prompt: String
    @Binding var text: String
    var submit: (() -> Void)?

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 19, weight: .medium))
                .foregroundStyle(AppPalette.muted)
            TextField(prompt, text: $text)
                .font(AppTypography.body)
                .submitLabel(.search)
                .onSubmit { submit?() }
            if !text.isEmpty {
                Button("Clear search", systemImage: "xmark.circle.fill") { text = "" }
                    .labelStyle(.iconOnly)
                    .foregroundStyle(AppPalette.subdued)
            }
        }
        .padding(.horizontal, AppSpacing.controlHorizontal)
        .frame(minHeight: 56)
        .background(AppPalette.control, in: RoundedRectangle(cornerRadius: AppRadius.control, style: .continuous))
    }
}

private struct SearchFieldPreview: View {
    @State private var text = "pizza"
    var body: some View { SearchField(prompt: "Food name", text: $text) }
}

#Preview {
    SearchFieldPreview()
        .padding()
        .background(AppPalette.paper)
}

