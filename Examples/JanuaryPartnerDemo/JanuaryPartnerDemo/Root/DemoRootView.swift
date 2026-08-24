import SwiftUI

struct DemoRootView: View {
    @Bindable var model: DemoAppModel

    var body: some View {
        ZStack {
            DemoPalette.paper.ignoresSafeArea()

            Group {
                switch model.state {
                case .loading, .connecting:
                    ProgressView("Preparing January…")
                case .ready:
                    if let client = model.client {
                        DemoTabView(client: client)
                    }
                case .failed(let message):
                    ContentUnavailableView(
                        "Couldn’t initialize the SDK",
                        systemImage: "exclamationmark.triangle",
                        description: Text(message)
                    )
                }
            }
        }
        .task {
            await model.bootstrap()
        }
    }
}
