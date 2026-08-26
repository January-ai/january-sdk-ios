import SwiftUI

struct ScreenShell<Content: View>: View {
    private let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            content
            Spacer(minLength: 0)
        }
            .padding(.horizontal, AppSpacing.screen)
    }
}

#Preview {
    ScreenShell {
        Text("Screen content")
            .appCard()
    }
    .padding(.vertical)
    .background(AppPalette.paper)
}
