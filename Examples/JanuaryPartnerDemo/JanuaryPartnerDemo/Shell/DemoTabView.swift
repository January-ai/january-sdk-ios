import SwiftUI
import JanuaryPartnerSDK

struct DemoTabView: View {
    let client: JanuaryPartnerClient
    @State private var isShowingSettings = false

    var body: some View {
        TabView {
            Tab("Search", systemImage: "magnifyingglass") {
                SearchView(client: client, settingsAction: showSettings)
            }

            Tab("Scan", systemImage: "camera.viewfinder") {
                ScanView(client: client, settingsAction: showSettings)
            }

            Tab("Food Logs", systemImage: "list.bullet.rectangle") {
                FoodLogsView(client: client, settingsAction: showSettings)
            }

            Tab("Glucose", systemImage: "chart.xyaxis.line") {
                GlucoseView(client: client, settingsAction: showSettings)
            }
        }
        .tabBarMinimizeBehavior(.onScrollDown)
        .tint(DemoPalette.ink)
        .background(Color.clear)
        .sheet(isPresented: $isShowingSettings) {
            DemoSettingsView()
        }
    }

    private func showSettings() {
        isShowingSettings = true
    }
}
