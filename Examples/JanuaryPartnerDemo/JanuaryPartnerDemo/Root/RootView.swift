import SwiftUI

struct RootView: View {
    @Bindable var model: AppModel

    var body: some View {
        ZStack {
            AppPalette.paper.ignoresSafeArea()

            Group {
                switch model.state {
                case .loading, .connecting:
                    VStack(spacing: 14) {
                        LoadingSpinner(color: AppPalette.green, size: 30)
                        Text("Preparing January…")
                            .font(.headline)
                            .foregroundStyle(AppPalette.muted)
                    }
                case .ready:
                    if let client = model.client {
                        AppTabView(client: client)
                            .environment(model.userSession)
                    }
                case .failed(let message):
                    ScreenShell {
                        EmptyStateCard(
                            title: "Couldn’t initialize the SDK",
                            message: message,
                            symbol: "exclamationmark.triangle"
                        )
                    }
                }
            }
        }
        .task {
            await model.bootstrap()
        }
    }
}
