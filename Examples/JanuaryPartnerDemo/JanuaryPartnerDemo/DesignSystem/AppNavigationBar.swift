import SwiftUI

enum AppNavigationTitleStyle {
    case centered
    case leading
}

private struct AppNavigationBarModifier<Leading: View, Trailing: View>: ViewModifier {
    let title: String
    let style: AppNavigationTitleStyle
    let leading: Leading
    let trailing: Trailing

    func body(content: Content) -> some View {
        content
            .navigationTitle(style == .leading ? title : "")
            .navigationBarTitleDisplayMode(style == .leading ? .large : .inline)
            .toolbar {
                if style == .centered {
                    ToolbarItem(placement: .principal) {
                        Text(title)
                            .font(AppTypography.navigationTitle)
                            .foregroundStyle(AppPalette.ink)
                    }
                }

                ToolbarItem(placement: .navigationBarLeading) {
                    leading
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    trailing
                }
            }
    }
}

extension View {
    func appNavigationBar(
        _ title: String,
        style: AppNavigationTitleStyle = .centered
    ) -> some View {
        modifier(
            AppNavigationBarModifier(
                title: title,
                style: style,
                leading: EmptyView(),
                trailing: EmptyView()
            )
        )
    }

    func appNavigationBar<Leading: View, Trailing: View>(
        _ title: String,
        style: AppNavigationTitleStyle = .centered,
        @ViewBuilder leading: () -> Leading,
        @ViewBuilder trailing: () -> Trailing
    ) -> some View {
        modifier(
            AppNavigationBarModifier(
                title: title,
                style: style,
                leading: leading(),
                trailing: trailing()
            )
        )
    }
}

#Preview("Centered") {
    NavigationStack {
        Color.clear
            .appNavigationBar("Food details")
    }
}

#Preview("Leading") {
    NavigationStack {
        Color.clear
            .appNavigationBar("Search", style: .leading)
    }
}
