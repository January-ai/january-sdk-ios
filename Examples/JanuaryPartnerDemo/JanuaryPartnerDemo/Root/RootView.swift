import SwiftUI

struct RootView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        ZStack {
            AppPalette.paper.ignoresSafeArea()

            switch model.state {
            case .loading, .connecting:
                ProgressView("Connecting to January…")
                    .foregroundStyle(AppPalette.body)
            case .ready:
                if let client = model.client {
                    VStack(spacing: 0) {
                        if model.isUsingDevelopmentAuthentication {
                            DevelopmentAuthenticationBanner()
                        }
                        AppTabView(client: client)
                            .environmentObject(model.userSession)
                    }
                }
            case .setupRequired(let detail):
                DemoSetupView(detail: detail)
            case .failed(let message):
                DemoSetupView(detail: message)
            }
        }
        .task {
            await model.bootstrap()
        }
    }
}

private struct DemoSetupView: View {
    let detail: String?

    var body: some View {
        ScrollView {
            ScreenShell {
                VStack(alignment: .leading, spacing: 24) {
                    VStack(alignment: .leading, spacing: 12) {
                        Image(systemName: "sparkles")
                            .font(.system(size: 24, weight: .semibold))
                            .foregroundStyle(AppPalette.green)
                            .frame(width: 48, height: 48)
                            .background(AppPalette.targetBand, in: Circle())

                        Text("Welcome to January")
                            .font(AppTypography.screenTitle)
                            .foregroundStyle(AppPalette.ink)

                        Text("Start the local token server, then point this demo at it. Your January API key stays on the server.")
                            .font(AppTypography.body)
                            .foregroundStyle(AppPalette.body)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    if let detail, !detail.isEmpty {
                        Label(detail, systemImage: "info.circle.fill")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(AppPalette.goldText)
                            .padding(14)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(AppPalette.goldBackground, in: RoundedRectangle(cornerRadius: AppRadius.control, style: .continuous))
                    }

                    VStack(alignment: .leading, spacing: 0) {
                        SetupOption(
                            number: "1",
                            title: "Start the token server",
                            badge: "Local",
                            message: "In january-server-sdk-node, run npm run demo:token-server."
                        )

                        Divider()
                            .overlay(AppPalette.divider)
                            .padding(.vertical, 18)

                        SetupOption(
                            number: "2",
                            title: "Connect this app",
                            badge: "Client token",
                            message: "Add the three environment variables from the README to the Xcode scheme."
                        )
                    }
                    .appCard()

                    VStack(alignment: .leading, spacing: 8) {
                        SectionLabel("Where to configure")
                            .padding(.horizontal, 0)

                        Text("Product → Scheme → Edit Scheme")
                            .font(AppTypography.bodyStrong)
                            .foregroundStyle(AppPalette.ink)

                        Text("Add the token URL, demo session token, and end-user ID under Run → Arguments.")
                            .font(.system(size: 15))
                            .foregroundStyle(AppPalette.body)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .appCard()
                }
                .frame(maxWidth: 680)
            }
            .padding(.vertical, 40)
        }
        .appBackground()
    }
}

private struct SetupOption: View {
    let number: String
    let title: String
    let badge: String
    let message: String

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Text(number)
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundStyle(AppPalette.greenText)
                .frame(width: 28, height: 28)
                .background(AppPalette.targetBand, in: Circle())

            VStack(alignment: .leading, spacing: 7) {
                Text(badge.uppercased())
                    .font(.system(size: 10, weight: .bold))
                    .tracking(0.6)
                    .foregroundStyle(AppPalette.greenText)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(AppPalette.targetBand, in: Capsule())

                Text(title)
                    .font(AppTypography.bodyStrong)
                    .foregroundStyle(AppPalette.ink)

                Text(message)
                    .font(.system(size: 15))
                    .foregroundStyle(AppPalette.body)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

private struct DevelopmentAuthenticationBanner: View {
    var body: some View {
        Label(
            "Local testing mode — do not distribute this build with a debug-only server API key.",
            systemImage: "exclamationmark.triangle.fill"
        )
        .font(.system(size: 13, weight: .semibold))
        .foregroundStyle(AppPalette.goldText)
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity)
        .background(AppPalette.goldBackground)
        .accessibilityLabel("Warning: local testing mode. Do not distribute this build with a debug-only server API key.")
    }
}

#Preview {
    RootView()
        .environmentObject(AppModel(authentication: .setupRequired()))
}
