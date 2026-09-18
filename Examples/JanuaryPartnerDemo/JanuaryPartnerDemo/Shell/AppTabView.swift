import SwiftUI
import January

struct AppTabView: View {
    let client: JanuaryClient
    @State private var isShowingSettings = false

    var body: some View {
        TabView {
            SearchView(client: client, settingsAction: showSettings)
                .tabItem {
                    Label("Search", systemImage: "magnifyingglass")
                        .accessibilityIdentifier("tab-search")
                }

            ScanView(client: client, settingsAction: showSettings)
                .tabItem {
                    Label("Scan", systemImage: "camera.viewfinder")
                        .accessibilityIdentifier("tab-scan")
                }

            FoodLogsView(client: client, settingsAction: showSettings)
                .tabItem {
                    Label("Food Logs", systemImage: "list.bullet.rectangle")
                        .accessibilityIdentifier("tab-food-logs")
                }

            GlucoseView(client: client, settingsAction: showSettings)
                .tabItem {
                    Label("Glucose", systemImage: "chart.xyaxis.line")
                        .accessibilityIdentifier("tab-glucose")
                }
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
