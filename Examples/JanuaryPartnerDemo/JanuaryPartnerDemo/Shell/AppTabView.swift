import SwiftUI
import January

struct AppTabView: View {
    let client: JanuaryClient
    @State private var isShowingSettings = false

    var body: some View {
        TabView {
            SearchView(client: client, settingsAction: showSettings)
                .tabItem { Label("Search", systemImage: "magnifyingglass") }

            ScanView(client: client, settingsAction: showSettings)
                .tabItem { Label("Scan", systemImage: "camera.viewfinder") }

            FoodLogsView(client: client, settingsAction: showSettings)
                .tabItem { Label("Food Logs", systemImage: "list.bullet.rectangle") }

            GlucoseView(client: client, settingsAction: showSettings)
                .tabItem { Label("Glucose", systemImage: "chart.xyaxis.line") }
        }
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
