import SwiftUI
import JanuarySDK

struct AppTabView: View {
    let client: JanuaryClient
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
        .tint(AppPalette.ink)
        .background(Color.clear)
        .sheet(isPresented: $isShowingSettings) {
            SettingsView()
        }
    }

    private func showSettings() {
        isShowingSettings = true
    }
}
