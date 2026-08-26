import SwiftUI

struct AppNavigationButton: View {
    enum Kind {
        case back
        case close
        case done
        case add
        case edit
        case settings
    }

    let kind: Kind
    let title: String
    let action: () -> Void

    init(_ kind: Kind, title: String? = nil, action: @escaping () -> Void) {
        self.kind = kind
        self.title = title ?? kind.defaultTitle
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            if let systemImage = kind.systemImage {
                if kind.isIconOnly {
                    Label(title, systemImage: systemImage)
                        .labelStyle(.iconOnly)
                } else {
                    Label(title, systemImage: systemImage)
                }
            } else {
                Text(title)
            }
        }
        .font(.system(size: 16, weight: .semibold))
        .tint(kind.tint)
        .accessibilityLabel(title)
    }
}

private extension AppNavigationButton.Kind {
    var defaultTitle: String {
        switch self {
        case .back: "Back"
        case .close: "Close"
        case .done: "Done"
        case .add: "Add"
        case .edit: "Edit"
        case .settings: "Settings"
        }
    }

    var systemImage: String? {
        switch self {
        case .back: "chevron.left"
        case .close: "xmark"
        case .add: "plus"
        case .settings: "gearshape"
        case .done, .edit: nil
        }
    }

    var isIconOnly: Bool {
        switch self {
        case .back, .close, .add, .settings: true
        case .done, .edit: false
        }
    }

    var tint: Color {
        switch self {
        case .back, .close, .add, .settings: AppPalette.ink
        case .done, .edit: AppPalette.goldText
        }
    }
}

#Preview {
    NavigationStack {
        Color.clear
            .appNavigationBar("Add food") {
                AppNavigationButton(.close, action: {})
            } trailing: {
                AppNavigationButton(.done, action: {})
            }
    }
}
